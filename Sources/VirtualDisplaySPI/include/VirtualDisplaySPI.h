// Private CoreGraphics virtual-display interfaces.
//
// CGVirtualDisplay is not in the public SDK. The class, method, and property
// names below are the Objective-C selectors the framework actually exports.
// They are declared here so Swift can call them through a bridging header
// (Xcode) or this clang module (SwiftPM). This file is an original declaration
// of that SPI. It is not taken from BetterDisplay.
//
// Shape checked against public descriptions of the same symbols:
// Khaos Tian's CGVirtualDisplay class dump, Chromium's
// ui/display/mac/test/virtual_display_mac_util.mm, and the MIT-licensed
// DeskPad header that wraps the same classes.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface CGVirtualDisplayMode : NSObject
@property (readonly, nonatomic) double refreshRate;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
- (instancetype)initWithWidth:(NSUInteger)width
                        height:(NSUInteger)height
                   refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic) unsigned int hiDPI;
- (instancetype)init;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property (retain, nonatomic, nullable) NSString *name;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int serialNum;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) CGPoint redPrimary;
@property (nonatomic) CGPoint greenPrimary;
@property (nonatomic) CGPoint bluePrimary;
@property (nonatomic) CGPoint whitePoint;
- (instancetype)init;
- (void)setDispatchQueue:(dispatch_queue_t)queue;
@end

@interface CGVirtualDisplay : NSObject
@property (readonly, nonatomic) CGDirectDisplayID displayID;
- (nullable instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

/// YES only when the private classes and the two methods we call are present.
BOOL PhoneScreenVirtualDisplayAPIAvailable(void);

/// Create a virtual display and apply one mode. The object must be retained;
/// releasing it removes the display. Returns nil and an error string on failure.
/// `hiDPI` is 0 or 1. When it is 1, `modeWidth`/`modeHeight` are the point size
/// and the framebuffer is 2× that (the caller passes already-halved dimensions).
CGVirtualDisplay *_Nullable PhoneScreenCreateVirtualDisplay(
    NSString *name,
    unsigned int maxPixelsWide,
    unsigned int maxPixelsHigh,
    double millimetersWide,
    double millimetersHigh,
    unsigned int modeWidth,
    unsigned int modeHeight,
    double refreshRate,
    unsigned int hiDPI,
    NSString *_Nullable __autoreleasing *_Nullable errorOut);

/// Create a virtual display registering several modes at once (sizes as
/// parallel NSNumber arrays). The first entry is the preferred initial mode.
CGVirtualDisplay *_Nullable PhoneScreenCreateVirtualDisplayWithModes(
    NSString *name,
    unsigned int maxPixelsWide,
    unsigned int maxPixelsHigh,
    double millimetersWide,
    double millimetersHigh,
    NSArray<NSNumber *> *widths,
    NSArray<NSNumber *> *heights,
    double refreshRate,
    unsigned int hiDPI,
    NSString *_Nullable __autoreleasing *_Nullable errorOut);

NS_ASSUME_NONNULL_END
