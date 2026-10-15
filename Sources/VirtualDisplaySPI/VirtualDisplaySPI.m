#import "VirtualDisplaySPI.h"

#import <dlfcn.h>
#import <objc/runtime.h>

static void PhoneScreenLoadCoreGraphics(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY);
    });
}

static dispatch_queue_t PhoneScreenVirtualDisplayQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("com.phonescreen.virtual-display", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static void PhoneScreenSetError(NSString *_Nullable *_Nullable errorOut, NSString *message) {
    if (errorOut != NULL) {
        *errorOut = message;
    }
}

BOOL PhoneScreenVirtualDisplayAPIAvailable(void) {
    PhoneScreenLoadCoreGraphics();
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");
    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    if (displayClass == Nil || descriptorClass == Nil || settingsClass == Nil || modeClass == Nil) {
        return NO;
    }
    if (![displayClass instancesRespondToSelector:@selector(initWithDescriptor:)]) {
        return NO;
    }
    if (![displayClass instancesRespondToSelector:@selector(applySettings:)]) {
        return NO;
    }
    if (![modeClass instancesRespondToSelector:@selector(initWithWidth:height:refreshRate:)]) {
        return NO;
    }
    return YES;
}

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
    NSString *_Nullable __autoreleasing *_Nullable errorOut) {
    if (!PhoneScreenVirtualDisplayAPIAvailable()) {
        PhoneScreenSetError(errorOut, @"这台 Mac 的 CoreGraphics 没有 CGVirtualDisplay，无法创建虚拟显示器。");
        return nil;
    }

    CGVirtualDisplayDescriptor *descriptor = [[CGVirtualDisplayDescriptor alloc] init];
    if (descriptor == nil) {
        PhoneScreenSetError(errorOut, @"CGVirtualDisplayDescriptor 初始化失败。");
        return nil;
    }

    descriptor.name = name;
    descriptor.maxPixelsWide = maxPixelsWide;
    descriptor.maxPixelsHigh = maxPixelsHigh;
    descriptor.sizeInMillimeters = CGSizeMake(millimetersWide, millimetersHigh);
    // macOS 14 rejects a zero vendor ID and wants a stable serial for the panel.
    descriptor.vendorID = 0x5053;
    descriptor.productID = 0x0001;
    descriptor.serialNum = 0x17E0;
    // sRGB primaries so the display is not given a degenerate color space.
    descriptor.redPrimary = CGPointMake(0.6400, 0.3300);
    descriptor.greenPrimary = CGPointMake(0.3000, 0.6000);
    descriptor.bluePrimary = CGPointMake(0.1500, 0.0600);
    descriptor.whitePoint = CGPointMake(0.3127, 0.3290);

    if ([descriptor respondsToSelector:@selector(setDispatchQueue:)]) {
        [descriptor setDispatchQueue:PhoneScreenVirtualDisplayQueue()];
    }

    CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:descriptor];
    if (display == nil) {
        PhoneScreenSetError(errorOut, @"CGVirtualDisplay 初始化失败。");
        return nil;
    }

    CGVirtualDisplayMode *mode = [[CGVirtualDisplayMode alloc] initWithWidth:modeWidth
                                                                       height:modeHeight
                                                                  refreshRate:refreshRate];
    CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
    if (hiDPI != 0 && modeWidth >= 2 && modeHeight >= 2) {
        CGVirtualDisplayMode *half = [[CGVirtualDisplayMode alloc] initWithWidth:modeWidth / 2
                                                                           height:modeHeight / 2
                                                                      refreshRate:refreshRate];
        settings.modes = @[ mode, half ];
    } else {
        settings.modes = @[ mode ];
    }
    settings.hiDPI = hiDPI == 0 ? 0 : 1;

    if (![display applySettings:settings]) {
        PhoneScreenSetError(errorOut, @"applySettings 被系统拒绝。可以换一个宽高或关闭 HiDPI 再试。");
        return nil;
    }
    if (display.displayID == 0) {
        PhoneScreenSetError(errorOut, @"虚拟显示器已创建，但系统没有分配 display ID。");
        return nil;
    }
    return display;
}

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
    NSString *_Nullable __autoreleasing *_Nullable errorOut) {
    if (!PhoneScreenVirtualDisplayAPIAvailable()) {
        PhoneScreenSetError(errorOut, @"这台 Mac 的 CoreGraphics 没有 CGVirtualDisplay，无法创建虚拟显示器。");
        return nil;
    }
    if (widths.count == 0 || widths.count != heights.count) {
        PhoneScreenSetError(errorOut, @"模式列表为空。");
        return nil;
    }
    CGVirtualDisplayDescriptor *descriptor = [[CGVirtualDisplayDescriptor alloc] init];
    if (descriptor == nil) {
        PhoneScreenSetError(errorOut, @"CGVirtualDisplayDescriptor 初始化失败。");
        return nil;
    }
    descriptor.name = name;
    descriptor.maxPixelsWide = maxPixelsWide;
    descriptor.maxPixelsHigh = maxPixelsHigh;
    descriptor.sizeInMillimeters = CGSizeMake(millimetersWide, millimetersHigh);
    descriptor.vendorID = 0x5053;
    descriptor.productID = 0x0001;
    descriptor.serialNum = 0x17E0;
    descriptor.redPrimary = CGPointMake(0.6400, 0.3300);
    descriptor.greenPrimary = CGPointMake(0.3000, 0.6000);
    descriptor.bluePrimary = CGPointMake(0.1500, 0.0600);
    descriptor.whitePoint = CGPointMake(0.3127, 0.3290);
    if ([descriptor respondsToSelector:@selector(setDispatchQueue:)]) {
        [descriptor setDispatchQueue:PhoneScreenVirtualDisplayQueue()];
    }
    CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:descriptor];
    if (display == nil) {
        PhoneScreenSetError(errorOut, @"CGVirtualDisplay 初始化失败。");
        return nil;
    }
    NSMutableArray<CGVirtualDisplayMode *> *modes = [NSMutableArray array];
    for (NSUInteger i = 0; i < widths.count; i++) {
        [modes addObject:[[CGVirtualDisplayMode alloc] initWithWidth:widths[i].unsignedIntegerValue
                                                              height:heights[i].unsignedIntegerValue
                                                         refreshRate:refreshRate]];
    }
    CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
    settings.modes = modes;
    settings.hiDPI = hiDPI == 0 ? 0 : 1;
    if (![display applySettings:settings]) {
        PhoneScreenSetError(errorOut, @"applySettings 被系统拒绝。可以换一个宽高或关闭 HiDPI 再试。");
        return nil;
    }
    if (display.displayID == 0) {
        PhoneScreenSetError(errorOut, @"虚拟显示器已创建，但系统没有分配 display ID。");
        return nil;
    }
    return display;
}
