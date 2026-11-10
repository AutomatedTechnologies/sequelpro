//
//  SPWelcomeController.m
//  sequel-pro
//
//  See SPWelcomeController.h. The conforming pattern is the estate's
//  own: DistroWelcomeController (Distro) for the SDS-8 layout and
//  version-at-foot form, APDMainController presentWelcome
//  (AirPods Max Diagnostics) for the AppIcon image view + pulse.
//

#import "SPWelcomeController.h"

static NSTextField *SPWelcomeLabel(NSString *text, CGFloat size, BOOL bold, NSColor *color)
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
	[label setStringValue:text];
	[label setFont:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size]];
	[label setTextColor:color];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setAlignment:NSTextAlignmentCenter];
	return label;
}

@implementation SPWelcomeController

- (id)init
{
	NSRect frame = NSMakeRect(0, 0, 480, 460);
	NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
		styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
		  backing:NSBackingStoreBuffered
			defer:NO] autorelease];
	[window setTitle:@"Welcome to Sequel Pro"];
	[window setReleasedWhenClosed:NO];
	self = [super initWithWindow:window];
	if (self) {
		NSView *content = [window contentView];
		CGFloat w = NSWidth(frame);
		CGFloat h = NSHeight(frame);

		// SDS-10 10.1.2: the welcome logo IS the bundle AppIcon
		// composition — the image is the app's own application icon,
		// not a redrawn or substitute mark.
		_iconView = [[NSImageView alloc] initWithFrame:NSMakeRect((w - 132) / 2, h - 48 - 132, 132, 132)];
		[_iconView setImage:[NSApp applicationIconImage]];
		[_iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
		[content addSubview:_iconView];

		NSTextField *name = SPWelcomeLabel(@"Sequel Pro", 28, YES, [NSColor blackColor]);
		[name setFrame:NSMakeRect(40, NSMinY([_iconView frame]) - 52, w - 80, 36)];
		[content addSubview:name];

		NSTextField *signature = SPWelcomeLabel(@"Detroit Automation Academy", 13, NO,
			[NSColor colorWithCalibratedWhite:0.27 alpha:1.0]);
		[signature setFrame:NSMakeRect(40, NSMinY([name frame]) - 28, w - 80, 20)];
		[content addSubview:signature];

		NSTextField *copyLine = SPWelcomeLabel(
			@"Manage MySQL and MariaDB databases on macOS High Sierra.", 12.5, NO, [NSColor blackColor]);
		[copyLine setFrame:NSMakeRect(50, NSMinY([signature frame]) - 40, w - 100, 20)];
		[content addSubview:copyLine];

		// SDS-10 10.2: the version line is read from the bundle's
		// own Info.plist at runtime (CFBundleVersion) — never
		// hardcoded. SPAboutController shows the same runtime
		// string in the About panel (10.2.3).
		NSString *buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		if (![buildVersion length]) {
			buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		}
		NSTextField *version = SPWelcomeLabel(
			[NSString stringWithFormat:@"Version %@", buildVersion ? buildVersion : @""], 12, NO,
			[NSColor colorWithCalibratedWhite:0.27 alpha:1.0]);
		[version setFrame:NSMakeRect(40, 14, w - 80, 18)];
		[content addSubview:version];

		NSButton *continueButton = [[[NSButton alloc] initWithFrame:NSMakeRect((w - 140) / 2, 44, 140, 32)] autorelease];
		[continueButton setTitle:@"Continue"];
		[continueButton setBezelStyle:NSBezelStyleRounded];
		[continueButton setFont:[NSFont systemFontOfSize:13]];
		[continueButton setTarget:self];
		[continueButton setAction:@selector(continuePressed:)];
		[continueButton setKeyEquivalent:@"\r"];
		[content addSubview:continueButton];

		[window center];
	}
	return self;
}

- (void)dealloc
{
	[_pulseTimer invalidate];
	[_pulseTimer release];
	[_iconView release];
	[_startupSound stop];
	[_startupSound release];
	[super dealloc];
}

// SDS-8 motion: a gentle pulse on the AppIcon mark while the welcome
// is up; static under Reduce Motion (accessibilityDisplayShouldReduceMotion).
- (void)startPulseIfAllowed
{
	if ([[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion]) return;
	if (_pulseTimer) return;
	_pulseTimer = [[NSTimer scheduledTimerWithTimeInterval:0.9
		target:self selector:@selector(tickPulse:) userInfo:nil repeats:YES] retain];
}

- (void)tickPulse:(NSTimer *)timer
{
	_pulseUp = !_pulseUp;
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
		[ctx setDuration:0.85];
		[[_iconView animator] setAlphaValue:_pulseUp ? 0.72 : 1.0];
	} completionHandler:nil];
}

// SDS-10 10.3 / SDS-8 addendum: startup-sound.wav (byte-identical to
// the library master, bundled in Resources) plays ONCE when the
// welcome presents — system volume, no loop. Missing asset proceeds
// silently; there is no error surface for it.
- (void)playStartupSoundOnce
{
	if (_soundPlayed) return;
	_soundPlayed = YES;
	NSString *path = [[NSBundle mainBundle] pathForResource:@"startup-sound" ofType:@"wav"];
	if (path == nil) return;
	_startupSound = [[NSSound alloc] initWithContentsOfFile:path byReference:NO];
	[_startupSound play];
}

- (void)showWindow:(id)sender
{
	[super showWindow:sender];
	[self playStartupSoundOnce];
	[self startPulseIfAllowed];
}

- (void)continuePressed:(id)sender
{
	[_pulseTimer invalidate];
	[_pulseTimer release];
	_pulseTimer = nil;
	[[self window] close];
}

// Escape dismisses, exactly like Continue (SDS-8: user-driven dismissal).
- (void)cancelOperation:(id)sender
{
	[self continuePressed:sender];
}

@end
