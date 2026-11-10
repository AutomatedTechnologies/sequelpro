//
//  SPWelcomeController.h
//  sequel-pro
//
//  SDS-8 standard welcome screen + SDS-10 conformance (Project 04,
//  tranche SDS10-T4, 2026-11-10): presented at launch before use —
//  the app's AppIcon composition (drawn from [NSApp
//  applicationIconImage], the bundle's own appIcon.icns, per SDS-10
//  10.1.2), the app name, the Detroit Automation Academy signature
//  line, one line of copy, the build version read at runtime from
//  the bundle's own Info.plist (CFBundleVersion, SDS-10 10.2 — never
//  hardcoded), the standard startup sound played once (SDS-10
//  10.3), and a single user-driven Continue action. No auto-dismiss
//  timer, no blocking delay; the main document flow is unchanged.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Cocoa/Cocoa.h>

@interface SPWelcomeController : NSWindowController {
@private
	NSImageView *_iconView;
	NSTimer *_pulseTimer;
	BOOL _pulseUp;
	NSSound *_startupSound;
	BOOL _soundPlayed;
}

- (id)init;

@end
