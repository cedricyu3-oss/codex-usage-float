#import <Cocoa/Cocoa.h>

@interface UsageSurfaceView : NSView
@property(nonatomic, weak) id monitor;
@property(nonatomic) BOOL expanded;
@property(nonatomic) double primaryRemaining;
@property(nonatomic) double secondaryRemaining;
@property(nonatomic) NSPoint dragStart;
@property(nonatomic) NSPoint panelOriginAtDragStart;
@property(nonatomic) BOOL didDrag;
@end

@implementation UsageSurfaceView

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    if (self.expanded) {
        NSBezierPath *card = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:18 yRadius:18];
        [[NSColor colorWithWhite:0.0 alpha:0.06] setFill];
        [card fill];
        [[NSColor separatorColor] setStroke];
        card.lineWidth = 1;
        [card stroke];
        [self drawBarAtY:58 percentage:self.primaryRemaining color:NSColor.controlAccentColor];
        [self drawBarAtY:28 percentage:self.secondaryRemaining color:NSColor.controlAccentColor];
        return;
    }

    NSRect circleRect = NSInsetRect(bounds, 3, 3);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    [[NSColor colorWithWhite:0.0 alpha:0.06] setFill];
    [circle fill];

    NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    CGFloat radius = NSWidth(circleRect) / 2 - 3;
    NSBezierPath *track = [NSBezierPath bezierPath];
    [track appendBezierPathWithArcWithCenter:center radius:radius startAngle:90 endAngle:449 clockwise:NO];
    track.lineWidth = 3;
    [[NSColor separatorColor] setStroke];
    [track stroke];

    if (self.primaryRemaining > 0) {
        NSBezierPath *progress = [NSBezierPath bezierPath];
        CGFloat endAngle = 90 + 360 * MIN(MAX(self.primaryRemaining, 0), 100) / 100;
        [progress appendBezierPathWithArcWithCenter:center radius:radius startAngle:90 endAngle:endAngle clockwise:NO];
        progress.lineWidth = 3;
        progress.lineCapStyle = NSLineCapStyleRound;
        [NSColor.controlAccentColor setStroke];
        [progress stroke];
    }
}

- (void)drawBarAtY:(CGFloat)y percentage:(double)percentage color:(NSColor *)color {
    NSRect trackRect = NSMakeRect(20, y, NSWidth(self.bounds) - 40, 3);
    NSBezierPath *track = [NSBezierPath bezierPathWithRoundedRect:trackRect xRadius:1.5 yRadius:1.5];
    [[[NSColor separatorColor] colorWithAlphaComponent:0.45] setFill];
    [track fill];
    NSRect fillRect = trackRect;
    fillRect.size.width *= MIN(MAX(percentage, 0), 100) / 100;
    if (fillRect.size.width > 0) {
        NSBezierPath *fill = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:1.5 yRadius:1.5];
        [color setFill];
        [fill fill];
    }
}

- (void)mouseDown:(NSEvent *)event {
    self.dragStart = NSEvent.mouseLocation;
    self.panelOriginAtDragStart = self.window.frame.origin;
    self.didDrag = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint currentLocation = NSEvent.mouseLocation;
    CGFloat deltaX = currentLocation.x - self.dragStart.x;
    CGFloat deltaY = currentLocation.y - self.dragStart.y;
    if (hypot(deltaX, deltaY) < 3) {
        return;
    }
    self.didDrag = YES;
    NSPoint origin = NSMakePoint(self.panelOriginAtDragStart.x + deltaX, self.panelOriginAtDragStart.y + deltaY);
    [self.window setFrameOrigin:origin];
}

- (void)mouseUp:(NSEvent *)event {
    if (!self.didDrag) {
        [self.monitor togglePanel:nil];
    }
}

@end
