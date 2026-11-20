#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "ModiFITLogo" asset catalog image resource.
static NSString * const ACImageNameModiFITLogo AC_SWIFT_PRIVATE = @"ModiFITLogo";

/// The "WatchWorkoutMascot" asset catalog image resource.
static NSString * const ACImageNameWatchWorkoutMascot AC_SWIFT_PRIVATE = @"WatchWorkoutMascot";

#undef AC_SWIFT_PRIVATE
