import Foundation

struct WorkoutScanResult: Sendable {
    struct Line: Sendable {
        let text: String
        let page: Int
        let confidence: Float?
    }

    enum Issue: String, Sendable {
        case tooDark
        case blurry
        case textTooSmall
        case hardToRead
        case noText
        case pageUnreadable
        case noExercises

        var title: String {
            switch self {
            case .tooDark: "Image looks too dark"
            case .blurry: "Image looks blurry"
            case .textTooSmall: "Text is too small"
            case .hardToRead: "Text is hard to read"
            case .noText: "No text found"
            case .pageUnreadable: "Page could not be read"
            case .noExercises: "No exercises found"
            }
        }

        var message: String {
            switch self {
            case .tooDark: "Use brighter, even lighting or choose a brighter copy."
            case .blurry: "Hold the camera steady and focus on the text, or choose a sharper copy."
            case .textTooSmall: "Move closer or choose a higher-resolution image."
            case .hardToRead: "Try a clearer photo or a typed copy."
            case .noText: "Make sure the routine is visible in the photo or PDF."
            case .pageUnreadable: "Choose a clearer copy or add the missing exercises manually."
            case .noExercises: "Use the original to add your exercises manually."
            }
        }
    }

    struct Finding: Identifiable, Sendable {
        let id = UUID()
        let page: Int
        let issue: Issue

        var title: String {
            switch issue {
            case .noExercises: issue.title
            default: "Page \(page): \(issue.title)"
            }
        }
    }

    let lines: [Line]
    let findings: [Finding]

    var text: String { lines.map(\.text).joined(separator: "\n") }
}

enum WorkoutScanError: Error {
    case invalidImage
    case invalidPDF
    case lockedPDF
    case emptyPDF
}
