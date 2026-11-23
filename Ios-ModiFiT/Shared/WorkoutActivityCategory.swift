import HealthKit

// A person's explicit choice of a workout category supported by Apple Health.
enum WorkoutActivityCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case traditionalStrength
    case functionalStrength
    case highIntensityIntervals
    case mixedCardio
    case coreTraining
    case running
    case walking
    case cycling
    case yoga
    case pilates
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .traditionalStrength: "Traditional Strength Training"
        case .functionalStrength: "Functional Strength Training"
        case .highIntensityIntervals: "High Intensity Interval Training"
        case .mixedCardio: "Mixed Cardio"
        case .coreTraining: "Core Training"
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .other: "Other"
        }
    }

    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .traditionalStrength: .traditionalStrengthTraining
        case .functionalStrength: .functionalStrengthTraining
        case .highIntensityIntervals: .highIntensityIntervalTraining
        case .mixedCardio: .mixedCardio
        case .coreTraining: .coreTraining
        case .running: .running
        case .walking: .walking
        case .cycling: .cycling
        case .yoga: .yoga
        case .pilates: .pilates
        case .other: .other
        }
    }
}
