#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

static const NSInteger FiveHourWindowMinutes = 300;
static const NSInteger WeeklyWindowMinutes = 10080;
// Keep the monitor in the macOS menu bar. The older floating panel code is
// retained for compatibility, but is intentionally disabled by default.
static const BOOL ShowFloatingPanel = NO;

@class UsageMonitor;

@interface PassiveLabel : NSTextField
@end

@implementation PassiveLabel

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

@end

@interface UsageSurfaceView : NSView
@property(nonatomic, weak) UsageMonitor *monitor;
@property(nonatomic) BOOL expanded;
@property(nonatomic) double primaryRemaining;
@property(nonatomic) double secondaryRemaining;
@property(nonatomic) NSPoint dragStart;
@property(nonatomic) NSPoint panelOriginAtDragStart;
@property(nonatomic) BOOL didDrag;
@end

@interface UsageMonitor : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, strong) NSPanel *floatingPanel;
@property(nonatomic, strong) NSVisualEffectView *contentContainer;
@property(nonatomic, strong) UsageSurfaceView *panelBackground;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *primaryLabel;
@property(nonatomic, strong) NSTextField *secondaryLabel;
@property(nonatomic, strong) NSTextField *snapshotLabel;
@property(nonatomic, strong) NSTextField *compactTitleLabel;
@property(nonatomic, strong) NSTextField *compactPercentLabel;
@property(nonatomic, strong) NSDictionary *currentSnapshot;
@property(nonatomic) BOOL isExpanded;
@property(nonatomic) NSRect compactFrameBeforeExpansion;
@property(nonatomic) BOOL hasCompactFrameBeforeExpansion;
@end

@implementation UsageMonitor

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    self.dateFormatter.dateFormat = @"M月d日 HH:mm";

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"Codex · 7d --";
    self.statusItem.button.toolTip = @"Codex Usage Float";

    if (ShowFloatingPanel) {
        [self configureFloatingPanel];
    }

    [self reload:nil];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:20.0
                                                         target:self
                                                       selector:@selector(reload:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)reload:(id)sender {
    NSDictionary *snapshot = [self latestSnapshot];
    [self updateStatusItemWithSnapshot:snapshot];
}

- (NSDictionary *)latestSnapshot {
    NSURL *sessionsDirectory = [[[NSFileManager defaultManager] homeDirectoryForCurrentUser]
        URLByAppendingPathComponent:@".codex/sessions" isDirectory:YES];
    NSArray<NSURLResourceKey> *keys = @[NSURLContentModificationDateKey, NSURLIsRegularFileKey];
    NSDirectoryEnumerator<NSURL *> *enumerator = [[NSFileManager defaultManager]
        enumeratorAtURL:sessionsDirectory
        includingPropertiesForKeys:keys
        options:NSDirectoryEnumerationSkipsHiddenFiles
        errorHandler:nil];
    if (enumerator == nil) {
        return nil;
    }

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    for (NSURL *url in enumerator) {
        if (![url.pathExtension isEqualToString:@"jsonl"]) {
            continue;
        }
        NSNumber *isRegularFile = nil;
        NSDate *modifiedAt = nil;
        if (![url getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil] ||
            !isRegularFile.boolValue ||
            ![url getResourceValue:&modifiedAt forKey:NSURLContentModificationDateKey error:nil]) {
            continue;
        }
        [candidates addObject:@{ @"url": url, @"modifiedAt": modifiedAt }];
    }

    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [right[@"modifiedAt"] compare:left[@"modifiedAt"]];
    }];

    NSUInteger limit = MIN(candidates.count, 40);
    for (NSUInteger index = 0; index < limit; index++) {
        NSDictionary *snapshot = [self latestSnapshotInFile:candidates[index][@"url"]
                                                  modifiedAt:candidates[index][@"modifiedAt"]];
        if (snapshot != nil) {
            return snapshot;
        }
    }
    return nil;
}

- (NSDictionary *)latestSnapshotInFile:(NSURL *)url modifiedAt:(NSDate *)modifiedAt {
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if (content == nil) {
        return nil;
    }

    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
    for (NSInteger index = lines.count - 1; index >= 0; index--) {
        NSString *line = lines[(NSUInteger)index];
        if ([line rangeOfString:@"\"rate_limits\""].location == NSNotFound) {
            continue;
        }
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSDictionary *limits = [self findRateLimits:root];
        NSDictionary *first = [self validWindow:limits[@"primary"]];
        NSDictionary *second = [self validWindow:limits[@"secondary"]];
        NSDictionary *fiveHour = nil;
        NSDictionary *weekly = nil;
        for (NSDictionary *window in @[first ?: (id)NSNull.null, second ?: (id)NSNull.null]) {
            if (![window isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            if ([window[@"window_minutes"] integerValue] == FiveHourWindowMinutes) {
                fiveHour = window;
            } else if ([window[@"window_minutes"] integerValue] == WeeklyWindowMinutes) {
                weekly = window;
            }
        }
        if (weekly != nil) {
            NSMutableDictionary *snapshot = [@{ @"secondary": weekly, @"modifiedAt": modifiedAt } mutableCopy];
            if (fiveHour != nil) {
                snapshot[@"primary"] = fiveHour;
            }
            return snapshot;
        }
    }
    return nil;
}

- (NSDictionary *)findRateLimits:(id)node {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)node;
        id directLimits = dictionary[@"rate_limits"];
        if ([directLimits isKindOfClass:[NSDictionary class]]) {
            return directLimits;
        }
        for (id value in dictionary.allValues) {
            NSDictionary *found = [self findRateLimits:value];
            if (found != nil) {
                return found;
            }
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)node) {
            NSDictionary *found = [self findRateLimits:value];
            if (found != nil) {
                return found;
            }
        }
    }
    return nil;
}

- (NSDictionary *)validWindow:(id)window {
    if (![window isKindOfClass:[NSDictionary class]] ||
        ![window[@"used_percent"] isKindOfClass:[NSNumber class]] ||
        ![window[@"resets_at"] isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    NSInteger minutes = [window[@"window_minutes"] integerValue];
    return (minutes == FiveHourWindowMinutes || minutes == WeeklyWindowMinutes) ? window : nil;
}

- (void)updateStatusItemWithSnapshot:(NSDictionary *)snapshot {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Codex 使用额度"];

    if (snapshot == nil) {
        self.statusItem.button.title = @"Codex · 7d --";
        self.statusItem.button.toolTip = @"尚未找到 Codex 额度快照";
        [self addDisabledItem:@"尚未找到额度快照" toMenu:menu];
        [self addDisabledItem:@"先完成一次 Codex 对话后再刷新。" toMenu:menu];
    } else {
        NSDictionary *secondary = snapshot[@"secondary"];
        double secondaryRemaining = [self remainingPercentForWindow:secondary];
        NSString *secondaryText = [self percentText:secondaryRemaining];

        self.statusItem.button.title = [NSString stringWithFormat:@"Codex · 7d %@", secondaryText];
        self.statusItem.button.toolTip = @"Codex 额度剩余（本地快照）";
        [self addDisabledItem:@"Codex 使用额度" toMenu:menu];
        [menu addItem:[NSMenuItem separatorItem]];
        [self addDisabledItem:[self menuLineWithTitle:@"本周" window:secondary] toMenu:menu];
        NSDate *modifiedAt = snapshot[@"modifiedAt"];
        [self addDisabledItem:[NSString stringWithFormat:@"本地快照：%@", [self.dateFormatter stringFromDate:modifiedAt]] toMenu:menu];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"刷新" action:@selector(reload:) keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出 Codex Usage Float" action:@selector(terminate:) keyEquivalent:@"q"];
    quitItem.target = NSApp;
    [menu addItem:quitItem];
    self.statusItem.menu = menu;
    if (ShowFloatingPanel) {
        [self updateFloatingPanelWithSnapshot:snapshot];
    }
}

- (void)configureFloatingPanel {
    NSRect contentRect = NSMakeRect(0, 0, 68, 68);
    self.floatingPanel = [[NSPanel alloc] initWithContentRect:contentRect
                                                     styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
    self.floatingPanel.opaque = NO;
    self.floatingPanel.backgroundColor = NSColor.clearColor;
    self.floatingPanel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.floatingPanel.hasShadow = YES;
    self.floatingPanel.level = NSScreenSaverWindowLevel - 1;
    self.floatingPanel.hidesOnDeactivate = NO;
    self.floatingPanel.movableByWindowBackground = NO;
    self.floatingPanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                            NSWindowCollectionBehaviorFullScreenAuxiliary |
                                            NSWindowCollectionBehaviorStationary;

    // Use NSVisualEffectView to achieve native macOS frosted glass and vibrancy
    NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:contentRect];
    effectView.wantsLayer = YES;
    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effectView.material = NSVisualEffectMaterialHUDWindow;
    effectView.state = NSVisualEffectStateActive;
    effectView.layer.cornerRadius = 34.0;
    effectView.layer.masksToBounds = YES;
    
    self.contentContainer = effectView;
    self.floatingPanel.contentView = self.contentContainer;

    self.panelBackground = [[UsageSurfaceView alloc] initWithFrame:contentRect];
    self.panelBackground.monitor = self;
    self.panelBackground.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentContainer addSubview:self.panelBackground];

    self.titleLabel = [self labelWithFrame:NSMakeRect(20, 96, 280, 16)
                                      font:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold]
                                     color:NSColor.secondaryLabelColor];
    self.titleLabel.stringValue = @"CODEX  ·  使用额度";
    [self.panelBackground addSubview:self.titleLabel];

    self.primaryLabel = [self labelWithFrame:NSMakeRect(20, 66, 300, 17)
                                        font:[NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightSemibold]
                                       color:NSColor.controlAccentColor];
    self.secondaryLabel = [self labelWithFrame:NSMakeRect(20, 36, 300, 17)
                                          font:[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightMedium]
                                         color:NSColor.labelColor];
    self.snapshotLabel = [self labelWithFrame:NSMakeRect(20, 10, 300, 14)
                                          font:[NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular]
                                         color:NSColor.tertiaryLabelColor];
    [self.panelBackground addSubview:self.primaryLabel];
    [self.panelBackground addSubview:self.secondaryLabel];
    [self.panelBackground addSubview:self.snapshotLabel];

    self.compactTitleLabel = [self labelWithFrame:NSMakeRect(0, 39, 68, 14)
                                             font:[NSFont systemFontOfSize:10 weight:NSFontWeightBold]
                                            color:NSColor.secondaryLabelColor];
    self.compactTitleLabel.alignment = NSTextAlignmentCenter;
    self.compactTitleLabel.stringValue = @"5H";
    self.compactPercentLabel = [self labelWithFrame:NSMakeRect(0, 19, 68, 23)
                                               font:[NSFont monospacedDigitSystemFontOfSize:18 weight:NSFontWeightBold]
                                              color:NSColor.labelColor];
    self.compactPercentLabel.alignment = NSTextAlignmentCenter;
    [self.panelBackground addSubview:self.compactTitleLabel];
    [self.panelBackground addSubview:self.compactPercentLabel];

    self.isExpanded = NO;
    [self applyPanelLayoutAnimated:NO];
    [NSApp activateIgnoringOtherApps:YES];
    [self.floatingPanel makeKeyAndOrderFront:nil];
}

- (void)togglePanel:(id)sender {
    if (!self.isExpanded) {
        self.compactFrameBeforeExpansion = self.floatingPanel.frame;
        self.hasCompactFrameBeforeExpansion = YES;
    }
    self.isExpanded = !self.isExpanded;
    [self applyPanelLayoutAnimated:YES];
    [self updateFloatingPanelWithSnapshot:self.currentSnapshot];
}

- (void)applyPanelLayoutAnimated:(BOOL)animated {
    NSSize size = self.isExpanded ? NSMakeSize(340, 122) : NSMakeSize(68, 68);
    NSRect previousFrame = self.floatingPanel.frame;
    NSRect panelFrame;
    BOOL wasExpanded = self.panelBackground.expanded;
    if (!self.isExpanded && self.hasCompactFrameBeforeExpansion) {
        panelFrame = self.compactFrameBeforeExpansion;
        self.hasCompactFrameBeforeExpansion = NO;
    } else if (previousFrame.origin.x == 0 && previousFrame.origin.y == 0) {
        NSScreen *screen = NSScreen.mainScreen;
        NSRect visibleFrame = screen.visibleFrame;
        panelFrame = NSMakeRect(
            NSMaxX(visibleFrame) - size.width - 22,
            NSMaxY(visibleFrame) - size.height - 22,
            size.width,
            size.height
        );
    } else {
        NSPoint center = NSMakePoint(NSMidX(previousFrame), NSMidY(previousFrame));
        panelFrame = NSMakeRect(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height);
    }
    if (self.isExpanded) {
        panelFrame = [self constrainedPanelFrame:panelFrame onScreen:[self screenForPanelFrame:previousFrame]];
    }

    NSArray<NSView *> *details = @[self.titleLabel, self.primaryLabel, self.secondaryLabel, self.snapshotLabel];
    NSArray<NSView *> *compact = @[self.compactTitleLabel, self.compactPercentLabel];
    for (NSView *view in details) {
        view.hidden = NO;
        view.alphaValue = self.isExpanded ? (animated ? 0 : 1) : 0;
    }
    for (NSView *view in compact) {
        view.hidden = NO;
        view.alphaValue = self.isExpanded ? 1 : (animated ? 0 : 1);
    }
    self.panelBackground.expanded = self.isExpanded;
    self.contentContainer.frame = NSMakeRect(0, 0, size.width, size.height);
    self.panelBackground.frame = NSMakeRect(0, 0, size.width, size.height);
    self.compactTitleLabel.frame = NSMakeRect(0, 39, size.width, 14);
    self.compactPercentLabel.frame = NSMakeRect(0, 18, size.width, 23);
    
    CGFloat cornerRadius = self.isExpanded ? 18.0 : 34.0;
    [self.panelBackground setNeedsDisplay:YES];

    if (!animated || wasExpanded == self.isExpanded) {
        self.contentContainer.layer.cornerRadius = cornerRadius;
        [self.floatingPanel setFrame:panelFrame display:YES];
        for (NSView *view in details) {
            view.hidden = !self.isExpanded;
            view.alphaValue = self.isExpanded ? 1 : 0;
        }
        for (NSView *view in compact) {
            view.hidden = self.isExpanded;
            view.alphaValue = self.isExpanded ? 0 : 1;
        }
        return;
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.24;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // Animate corner radius of the visual effect view
        CABasicAnimation *radiusAnim = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
        radiusAnim.fromValue = @(self.isExpanded ? 34.0 : 18.0);
        radiusAnim.toValue = @(cornerRadius);
        radiusAnim.duration = 0.24;
        radiusAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.contentContainer.layer addAnimation:radiusAnim forKey:@"cornerRadius"];
        self.contentContainer.layer.cornerRadius = cornerRadius;

        [[self.floatingPanel animator] setFrame:panelFrame display:YES];
        for (NSView *view in details) {
            view.animator.alphaValue = self.isExpanded ? 1 : 0;
        }
        for (NSView *view in compact) {
            view.animator.alphaValue = self.isExpanded ? 0 : 1;
        }
    } completionHandler:^{
        for (NSView *view in details) {
            view.hidden = !self.isExpanded;
        }
        for (NSView *view in compact) {
            view.hidden = self.isExpanded;
        }
    }];
}

- (NSScreen *)screenForPanelFrame:(NSRect)frame {
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(center, screen.frame)) {
            return screen;
        }
    }
    return NSScreen.mainScreen;
}

- (NSRect)constrainedPanelFrame:(NSRect)frame onScreen:(NSScreen *)screen {
    NSRect visibleFrame = screen.visibleFrame;
    CGFloat inset = 12;
    frame.origin.x = MIN(MAX(frame.origin.x, NSMinX(visibleFrame) + inset), NSMaxX(visibleFrame) - NSWidth(frame) - inset);
    frame.origin.y = MIN(MAX(frame.origin.y, NSMinY(visibleFrame) + inset), NSMaxY(visibleFrame) - NSHeight(frame) - inset);
    return frame;
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [[PassiveLabel alloc] initWithFrame:frame];
    label.editable = NO;
    label.selectable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (void)updateFloatingPanelWithSnapshot:(NSDictionary *)snapshot {
    self.currentSnapshot = snapshot;
    if (snapshot == nil) {
        self.primaryLabel.stringValue = @"5小时  --";
        self.secondaryLabel.stringValue = @"本周    --";
        self.snapshotLabel.stringValue = @"完成一次 Codex 对话后自动显示";
        self.compactPercentLabel.stringValue = @"--";
        self.panelBackground.primaryRemaining = 0;
        self.panelBackground.secondaryRemaining = 0;
        [self.panelBackground setNeedsDisplay:YES];
        return;
    }

    NSDictionary *primary = snapshot[@"primary"];
    NSDictionary *secondary = snapshot[@"secondary"];
    double primaryRemaining = primary ? [self remainingPercentForWindow:primary] : 0;
    double secondaryRemaining = [self remainingPercentForWindow:secondary];
    self.primaryLabel.stringValue = primary ? [NSString stringWithFormat:@"5小时   ·   剩余 %@", [self percentText:primaryRemaining]] : @"5小时   ·   当前 Codex 未提供";
    self.secondaryLabel.stringValue = [NSString stringWithFormat:@"本周     ·   剩余 %@", [self percentText:secondaryRemaining]];
    NSDate *primaryReset = primary ? [NSDate dateWithTimeIntervalSince1970:[primary[@"resets_at"] doubleValue]] : nil;
    NSDate *secondaryReset = [NSDate dateWithTimeIntervalSince1970:[secondary[@"resets_at"] doubleValue]];
    self.snapshotLabel.stringValue = primary ? [NSString stringWithFormat:@"重置：%@  ·  %@", [self.dateFormatter stringFromDate:primaryReset], [self.dateFormatter stringFromDate:secondaryReset]] : [NSString stringWithFormat:@"本周重置：%@", [self.dateFormatter stringFromDate:secondaryReset]];
    self.compactTitleLabel.stringValue = primary ? @"5H" : @"7D";
    self.compactPercentLabel.stringValue = [self percentText:primary ? primaryRemaining : secondaryRemaining];
    self.panelBackground.primaryRemaining = primaryRemaining;
    self.panelBackground.secondaryRemaining = secondaryRemaining;
    [self.panelBackground setNeedsDisplay:YES];
}

- (void)addDisabledItem:(NSString *)title toMenu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.enabled = NO;
    [menu addItem:item];
}

- (double)remainingPercentForWindow:(NSDictionary *)window {
    return MIN(MAX(100.0 - [window[@"used_percent"] doubleValue], 0.0), 100.0);
}

- (NSString *)percentText:(double)value {
    return [NSString stringWithFormat:@"%.0f%%", round(value)];
}

- (NSString *)menuLineWithTitle:(NSString *)title window:(NSDictionary *)window {
    double remaining = [self remainingPercentForWindow:window];
    NSDate *resetDate = [NSDate dateWithTimeIntervalSince1970:[window[@"resets_at"] doubleValue]];
    return [NSString stringWithFormat:@"%@：剩余 %@ · 重置 %@", title, [self percentText:remaining], [self.dateFormatter stringFromDate:resetDate]];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        UsageMonitor *monitor = [[UsageMonitor alloc] init];
        application.delegate = monitor;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
