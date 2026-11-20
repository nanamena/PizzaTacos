import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "ModiFITLogo" asset catalog image resource.
    static let modiFITLogo = DeveloperToolsSupport.ImageResource(name: "ModiFITLogo", bundle: resourceBundle)

    /// The "ModiFiTMascot" asset catalog image resource.
    static let modiFiTMascot = DeveloperToolsSupport.ImageResource(name: "ModiFiTMascot", bundle: resourceBundle)

    /// The "WorkoutAnimationCurl1" asset catalog image resource.
    static let workoutAnimationCurl1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationCurl1", bundle: resourceBundle)

    /// The "WorkoutAnimationCurl2" asset catalog image resource.
    static let workoutAnimationCurl2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationCurl2", bundle: resourceBundle)

    /// The "WorkoutAnimationCycle1" asset catalog image resource.
    static let workoutAnimationCycle1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationCycle1", bundle: resourceBundle)

    /// The "WorkoutAnimationCycle2" asset catalog image resource.
    static let workoutAnimationCycle2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationCycle2", bundle: resourceBundle)

    /// The "WorkoutAnimationLegPress1" asset catalog image resource.
    static let workoutAnimationLegPress1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationLegPress1", bundle: resourceBundle)

    /// The "WorkoutAnimationLegPress2" asset catalog image resource.
    static let workoutAnimationLegPress2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationLegPress2", bundle: resourceBundle)

    /// The "WorkoutAnimationMelt1" asset catalog image resource.
    static let workoutAnimationMelt1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationMelt1", bundle: resourceBundle)

    /// The "WorkoutAnimationMelt2" asset catalog image resource.
    static let workoutAnimationMelt2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationMelt2", bundle: resourceBundle)

    /// The "WorkoutAnimationPulley1" asset catalog image resource.
    static let workoutAnimationPulley1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationPulley1", bundle: resourceBundle)

    /// The "WorkoutAnimationPulley2" asset catalog image resource.
    static let workoutAnimationPulley2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationPulley2", bundle: resourceBundle)

    /// The "WorkoutAnimationRest1" asset catalog image resource.
    static let workoutAnimationRest1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationRest1", bundle: resourceBundle)

    /// The "WorkoutAnimationRest2" asset catalog image resource.
    static let workoutAnimationRest2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationRest2", bundle: resourceBundle)

    /// The "WorkoutAnimationTreadmill1" asset catalog image resource.
    static let workoutAnimationTreadmill1 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationTreadmill1", bundle: resourceBundle)

    /// The "WorkoutAnimationTreadmill2" asset catalog image resource.
    static let workoutAnimationTreadmill2 = DeveloperToolsSupport.ImageResource(name: "WorkoutAnimationTreadmill2", bundle: resourceBundle)

    /// The "WorkoutCompletionMascot" asset catalog image resource.
    static let workoutCompletionMascot = DeveloperToolsSupport.ImageResource(name: "WorkoutCompletionMascot", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "ModiFITLogo" asset catalog image.
    static var modiFITLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .modiFITLogo)
#else
        .init()
#endif
    }

    /// The "ModiFiTMascot" asset catalog image.
    static var modiFiTMascot: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .modiFiTMascot)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCurl1" asset catalog image.
    static var workoutAnimationCurl1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationCurl1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCurl2" asset catalog image.
    static var workoutAnimationCurl2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationCurl2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCycle1" asset catalog image.
    static var workoutAnimationCycle1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationCycle1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCycle2" asset catalog image.
    static var workoutAnimationCycle2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationCycle2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationLegPress1" asset catalog image.
    static var workoutAnimationLegPress1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationLegPress1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationLegPress2" asset catalog image.
    static var workoutAnimationLegPress2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationLegPress2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationMelt1" asset catalog image.
    static var workoutAnimationMelt1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationMelt1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationMelt2" asset catalog image.
    static var workoutAnimationMelt2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationMelt2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationPulley1" asset catalog image.
    static var workoutAnimationPulley1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationPulley1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationPulley2" asset catalog image.
    static var workoutAnimationPulley2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationPulley2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationRest1" asset catalog image.
    static var workoutAnimationRest1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationRest1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationRest2" asset catalog image.
    static var workoutAnimationRest2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationRest2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationTreadmill1" asset catalog image.
    static var workoutAnimationTreadmill1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationTreadmill1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationTreadmill2" asset catalog image.
    static var workoutAnimationTreadmill2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutAnimationTreadmill2)
#else
        .init()
#endif
    }

    /// The "WorkoutCompletionMascot" asset catalog image.
    static var workoutCompletionMascot: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .workoutCompletionMascot)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "ModiFITLogo" asset catalog image.
    static var modiFITLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .modiFITLogo)
#else
        .init()
#endif
    }

    /// The "ModiFiTMascot" asset catalog image.
    static var modiFiTMascot: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .modiFiTMascot)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCurl1" asset catalog image.
    static var workoutAnimationCurl1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationCurl1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCurl2" asset catalog image.
    static var workoutAnimationCurl2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationCurl2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCycle1" asset catalog image.
    static var workoutAnimationCycle1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationCycle1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationCycle2" asset catalog image.
    static var workoutAnimationCycle2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationCycle2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationLegPress1" asset catalog image.
    static var workoutAnimationLegPress1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationLegPress1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationLegPress2" asset catalog image.
    static var workoutAnimationLegPress2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationLegPress2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationMelt1" asset catalog image.
    static var workoutAnimationMelt1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationMelt1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationMelt2" asset catalog image.
    static var workoutAnimationMelt2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationMelt2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationPulley1" asset catalog image.
    static var workoutAnimationPulley1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationPulley1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationPulley2" asset catalog image.
    static var workoutAnimationPulley2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationPulley2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationRest1" asset catalog image.
    static var workoutAnimationRest1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationRest1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationRest2" asset catalog image.
    static var workoutAnimationRest2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationRest2)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationTreadmill1" asset catalog image.
    static var workoutAnimationTreadmill1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationTreadmill1)
#else
        .init()
#endif
    }

    /// The "WorkoutAnimationTreadmill2" asset catalog image.
    static var workoutAnimationTreadmill2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutAnimationTreadmill2)
#else
        .init()
#endif
    }

    /// The "WorkoutCompletionMascot" asset catalog image.
    static var workoutCompletionMascot: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .workoutCompletionMascot)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

