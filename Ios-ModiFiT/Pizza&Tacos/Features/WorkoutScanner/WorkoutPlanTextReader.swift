import Foundation
import ImageIO
import PDFKit
import Vision
import CoreGraphics

enum WorkoutPlanTextReader {
    @concurrent static func read(_ data: Data, isPDF: Bool) async throws -> WorkoutScanResult {
        if !isPDF {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 3200
                  ] as CFDictionary) else {
                throw WorkoutScanError.invalidImage
            }
            return try await recognizeText(in: image, page: 1)
        }

        guard let document = PDFDocument(data: data) else { throw WorkoutScanError.invalidPDF }
        guard !document.isLocked else { throw WorkoutScanError.lockedPDF }
        guard document.pageCount > 0 else { throw WorkoutScanError.emptyPDF }

        var lines: [WorkoutScanResult.Line] = []
        var findings: [WorkoutScanResult.Finding] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            let pageNumber = index + 1
            guard let page = document.page(at: index) else {
                findings.append(.init(page: pageNumber, issue: .pageUnreadable))
                continue
            }
            let embedded = (page.string ?? "").split(whereSeparator: \.isNewline).map {
                WorkoutScanResult.Line(text: String($0), page: pageNumber, confidence: nil)
            }
            if embedded.contains(where: { hasExerciseStructure($0.text) }) {
                lines += embedded
                continue
            }
            let bounds = page.bounds(for: .cropBox)
            let longestSide = max(bounds.width, bounds.height)
            guard longestSide > 0 else {
                lines += embedded
                findings.append(.init(page: pageNumber, issue: .pageUnreadable))
                continue
            }
            let scale = 2200 / longestSide
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            guard let image = page.thumbnail(of: size, for: .cropBox).cgImage else {
                lines += embedded
                findings.append(.init(page: pageNumber, issue: .pageUnreadable))
                continue
            }
            do {
                let scanned = try await recognizeText(in: image, page: pageNumber)
                if scanned.lines.contains(where: { hasExerciseStructure($0.text) }) || embedded.isEmpty {
                    lines += scanned.lines
                    findings += scanned.findings
                } else {
                    lines += embedded
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lines += embedded
                findings.append(.init(page: pageNumber, issue: .pageUnreadable))
            }
        }
        return WorkoutScanResult(lines: lines, findings: findings)
    }

    private nonisolated static func hasExerciseStructure(_ text: String) -> Bool {
        guard text.contains(where: \.isLetter) else { return false }
        return text.firstMatch(of: #/\b\d{1,2}\s*[xX×]\s*\d{1,4}\b/#) != nil
            || text.firstMatch(of: #/(?i)\b\d{1,2}\s*(?:sets?|serie)\b/#) != nil
            || text.split(separator: "\t", omittingEmptySubsequences: false).count >= 3
    }

    private nonisolated static func recognizeText(in image: CGImage, page: Int) async throws -> WorkoutScanResult {
        try Task.checkCancellation()
        var documentRequest = RecognizeDocumentsRequest()
        documentRequest.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "it-IT"), Locale.Language(identifier: "en-US")]
        let documents = try? await documentRequest.perform(on: image)
        try Task.checkCancellation()

        let tables: [(CGRect, [(String, Float?)])] = (documents ?? []).flatMap { observation in
            observation.document.tables
        }.compactMap { table in
            guard let lines = normalizedTableLines(table), !lines.isEmpty else { return nil }
            return (table.boundingRegion.normalizedPath.boundingBox, lines)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["it-IT", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        try Task.checkCancellation()

        let observations = (request.results ?? []).filter { observation in
            !tables.contains { bounds, _ in bounds.contains(CGPoint(x: observation.boundingBox.midX, y: observation.boundingBox.midY)) }
        }.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations {
            let box = observation.boundingBox
            if let first = rows.last?.first?.boundingBox,
               abs(first.midY - box.midY) < min(first.height, box.height) / 2 {
                rows[rows.count - 1].append(observation)
            } else {
                rows.append([observation])
            }
        }
        var lines: [(CGFloat, WorkoutScanResult.Line)] = rows.map { row in
            let candidates = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first }
            let text = candidates.map(\.string).joined(separator: "\t")
            let confidence = candidates.map(\.confidence).min()
            return (row[0].boundingBox.midY, .init(text: text, page: page, confidence: confidence))
        }
        lines += tables.flatMap { bounds, tableLines in
            tableLines.enumerated().map { index, row in
                let y = bounds.maxY - CGFloat(index) * bounds.height / CGFloat(max(1, tableLines.count))
                return (y, WorkoutScanResult.Line(text: row.0, page: page, confidence: row.1))
            }
        }
        let recognized = lines.sorted { $0.0 > $1.0 }.map(\.1)
        let lowConfidence = recognized.contains { ($0.confidence ?? 1) < 0.45 }
        var issue: WorkoutScanResult.Issue?
        if recognized.isEmpty {
            let detected = try? await DetectTextRectanglesRequest().perform(on: image)
            let quality = imageQuality(image, textBoxes: [])
            if quality.brightness < 58 { issue = .tooDark }
            else if detected?.isEmpty == false && quality.sharpness < 85 { issue = .blurry }
            else { issue = detected?.isEmpty == false ? .hardToRead : .noText }
        } else if lowConfidence {
            let textBoxes = (request.results ?? []).map(\.boundingBox)
            let quality = imageQuality(image, textBoxes: textBoxes)
            if quality.brightness < 58 { issue = .tooDark }
            else if quality.sharpness < 85 { issue = .blurry }
            else if textBoxes.contains(where: { $0.height * CGFloat(image.height) < 12 }) { issue = .textTooSmall }
            else { issue = .hardToRead }
        }
        return WorkoutScanResult(lines: recognized,
                                 findings: issue.map { [.init(page: page, issue: $0)] } ?? [])
    }

    private nonisolated static func imageQuality(_ image: CGImage, textBoxes: [CGRect]) -> (brightness: Double, sharpness: Double) {
        let scale = 512.0 / Double(max(image.width, image.height))
        let width = max(1, Int(Double(image.width) * scale))
        let height = max(1, Int(Double(image.height) * scale))
        guard width > 2, height > 2 else { return (128, 1_000) }
        var pixels = [UInt8](repeating: 0, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else {
            return (128, 1_000)
        }
        let focus = textBoxes.reduce(CGRect.null) { $0.union($1) }
        let region = focus.isNull ? CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8) : focus
        let left = max(1, Int(region.minX * Double(width)))
        let right = min(width - 1, Int(region.maxX * Double(width)))
        let top = max(1, Int(region.minY * Double(height)))
        let bottom = min(height - 1, Int(region.maxY * Double(height)))
        guard left < right, top < bottom else { return (128, 1_000) }
        var brightness = 0.0
        var edgeEnergy = 0.0
        var count = 0.0
        for y in top..<bottom {
            for x in left..<right {
                let index = y * width + x
                let center = Double(pixels[index])
                brightness += center
                let laplacian = 4 * center - Double(pixels[index - 1]) - Double(pixels[index + 1])
                    - Double(pixels[index - width]) - Double(pixels[index + width])
                edgeEnergy += laplacian * laplacian
                count += 1
            }
        }
        return (brightness / count, edgeEnergy / count)
    }

    private nonisolated static func normalizedTableLines(_ table: DocumentObservation.Container.Table) -> [(String, Float?)]? {
        guard let header = table.rows.first else { return nil }
        let columnCount = (header.map(\.columnRange.upperBound).max() ?? -1) + 1
        let labels = (0..<columnCount).map { index in
            (header.first { $0.columnRange.contains(index) }?.content.text.transcript ?? "")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        func column(_ terms: [String]) -> Int? {
            labels.firstIndex { label in terms.contains { label.contains($0) } }
        }
        guard let name = column(["esercizio", "exercise", "movimento"]),
              let sets = column(["serie", "set"]),
              let reps = column(["ripet", "reps", "rep", "durata", "duration"]) else { return nil }
        let rest = column(["recuper", "rest", "pausa", "pause"])
        let mappedColumns = [name, sets, reps] + [rest].compactMap { $0 }
        guard Set(mappedColumns).count == mappedColumns.count else { return nil }
        let restIsMinutes = rest.map { labels[$0].contains("min") } ?? false

        return table.rows.indices.dropFirst().compactMap { rowIndex in
            let row = table.rows[rowIndex]
            func cell(at index: Int?) -> DocumentObservation.Container.Table.Cell? {
                guard let index else { return nil }
                return row.first { $0.columnRange.contains(index) }
            }
            func value(at index: Int?) -> String {
                cell(at: index)?.content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            let exercise = value(at: name)
            guard exercise.contains(where: \.isLetter) else { return nil }
            let restValue = value(at: rest)
            let text = [exercise, value(at: sets), value(at: reps),
                        restIsMinutes && !restValue.isEmpty ? "\(restValue) min" : restValue]
                .joined(separator: "\t")
            let confidence = mappedColumns.flatMap { cell(at: $0)?.content.text.lines.map(\.confidence) ?? [] }.min()
            return (text, confidence)
        }
    }
}
