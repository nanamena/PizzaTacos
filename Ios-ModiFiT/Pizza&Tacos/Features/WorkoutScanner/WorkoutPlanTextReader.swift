import Foundation
import ImageIO
import PDFKit
import Vision

enum WorkoutPlanTextReader {
    @concurrent static func read(_ data: Data, isPDF: Bool) async throws -> String {
        if !isPDF {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 3200
                  ] as CFDictionary) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return try recognizeText(in: VNImageRequestHandler(cgImage: image))
        }

        guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(text)
                continue
            }

            let bounds = page.bounds(for: .cropBox)
            let longestSide = max(bounds.width, bounds.height)
            guard longestSide > 0 else { continue }
            let scale = 2200 / longestSide
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let text = try autoreleasepool {
                guard let image = page.thumbnail(of: size, for: .cropBox).cgImage else { return "" }
                return try recognizeText(in: VNImageRequestHandler(cgImage: image))
            }
            pages.append(text)
        }
        return pages.joined(separator: "\n")
    }

    private nonisolated static func recognizeText(in handler: VNImageRequestHandler) throws -> String {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["it-IT", "en-US"]
        try handler.perform([request])
        try Task.checkCancellation()

        let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
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
        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\t")
        }.joined(separator: "\n")
    }
}
