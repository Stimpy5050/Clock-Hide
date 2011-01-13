/*
 *  Tweak.mm
 *  
 *  Created by David Ashman on 1/12/09.
 *  Copyright 2009 David Ashman. All rights reserved.
 *
 */

#include <substrate.h>
#include <UIKit/UIKit.h>
#include <TelephonyUI/TPLCDTextView.h>
#include <SpringBoard/SBApplication.h>
#include <SpringBoard/SBAwayView.h>
#include <SpringBoard/SBAwayDateView.h>
#include <SpringBoard/SBAwayController.h>
#include <SpringBoard/SBStatusBarController.h>
#include <Preferences/PSSpecifier.h>
#include <TelephonyUI/TPLCDView.h>
#include <Foundation/Foundation.h>

static NSString* prefsPath = @"/User/Library/Preferences/com.ashman.ClockHide.plist";
extern "C" UIImage* _UIImageWithName(NSString*);

static Class $SBStatusBarController;
static Class $SBAwayController;
static Class $SBAwayView;

static BOOL prefEnabled;
static BOOL prefStatusBar;
static BOOL prefShowDate;
static BOOL prefTransparentBackground;
static UIView* dateView;

static BOOL isVisible()
{
	if (!prefEnabled)
		return true;

	SBAwayController* sbac = [$SBAwayController sharedAwayController];
	return (sbac.isShowingMediaControls || sbac.isSyncing);
}

static UIView* topBar()
{
	SBAwayController* sbac = [$SBAwayController sharedAwayController];
	if (SBAwayView* sbav = [sbac awayView])
		return sbav.topBar;
}

static void preferences()
{
        prefEnabled = true;
        prefStatusBar = true;
        prefShowDate = false;
        prefTransparentBackground = false;

        if (NSMutableDictionary* prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath])
        {
                if (NSNumber* pref = [prefs objectForKey:@"Enabled"])
                        prefEnabled = [pref boolValue];

                if (NSNumber* pref = [prefs objectForKey:@"StatusBarTime"])
                        prefStatusBar = [pref boolValue];

                if (NSNumber* pref = [prefs objectForKey:@"ShowDate"])
                        prefShowDate = [pref boolValue];

                if (NSNumber* pref = [prefs objectForKey:@"TransparentDateBackground"])
                        prefTransparentBackground = [pref boolValue];
	}

	if (objc_getClass("UIStatusBar"))
		if (prefStatusBar && prefEnabled)
			[[UIApplication sharedApplication] addStatusBarItem:0];
		else
			[[UIApplication sharedApplication] removeStatusBarItem:0];

	dateView.hidden = !(prefEnabled && prefShowDate);
	[dateView setNeedsDisplay];
}

MSHook(void, ch_setIsLockVisible, SBStatusBarController *self, SEL sel, BOOL b, BOOL b2)
{
	if (!prefEnabled || !prefStatusBar)
	{
		_ch_setIsLockVisible(self, sel, b, b2);	
		return;
	}

	_ch_setIsLockVisible(self, sel, isVisible(), !isVisible());	
}

MSHook(void, noteSyncStateChanged, SBAwayController  *self, SEL sel)
{
	_noteSyncStateChanged(self, sel);
	if (prefEnabled)
		[topBar() setHidden:NO];
}

MSHook(void, ch_setIsShowingControls, SBAwayDateView *self, SEL sel, BOOL b)
{
	_ch_setIsShowingControls(self, sel, b);	
	if (prefEnabled)
		[topBar() setHidden:NO];
}

MSHook(CGRect, ch_middleFrame, SBAwayView *self, SEL sel)
{
	CGRect rect = _ch_middleFrame(self, sel);

	if (isVisible())
		return rect;

	int y = 20;
	if (prefShowDate)
		y += 20;

	return CGRectMake(rect.origin.x, y, rect.size.width, rect.size.height + (rect.origin.y - y));
}

@interface DateView : UIView
@end

@implementation DateView

-(void) drawRect:(struct CGRect) rect
{
	if (!prefTransparentBackground)
	{
		NSBundle* bundle = [NSBundle mainBundle];
		UIImage* image = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"FST_BG" ofType:@"png"]];
		if (image == nil)
			image = _UIImageWithName(@"Translucent_Base.png");
	
		[image drawInRect:self.bounds];
	}

	SBAwayView* av = (SBAwayView*) self.superview;
	if (SBAwayDateView* adv = av.dateView)
	{
		if (TPLCDTextView* label = MSHookIvar<TPLCDTextView*>(adv, "_titleLabel"))
		{
			[[UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1] set];
			[label.text drawInRect:self.bounds withFont:[UIFont boldSystemFontOfSize:14] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
		}
	}
}

@end

MSHook(id, awayViewInitWithFrame, SBAwayView *self, SEL sel, CGRect frame)
{
	self = _awayViewInitWithFrame(self, sel, frame);
	[self insertSubview:dateView aboveSubview:self.topBar];
	[dateView setNeedsDisplay];
	return self;
}

MSHook(id, ch_initWithFrame, SBAwayDateView *self, SEL sel, CGRect frame)
{
	self = _ch_initWithFrame(self, sel, frame);
	[dateView setNeedsDisplay];
	if (prefEnabled)
		[topBar() setHidden:NO];
	return self;
}

MSHook(void, setHidden, UIView* self, SEL sel, BOOL b)
{
	if (prefEnabled)
	{
		b = !isVisible();
		[self setUserInteractionEnabled:!b];

		dateView.hidden = (!b || !prefShowDate);

		if (prefStatusBar)
		{
			SBStatusBarController* sbController = [$SBStatusBarController sharedStatusBarController];
			[sbController setIsLockVisible:!b isTimeVisible:b];
		}
	}

	_setHidden(self, sel, b);
}

static void updatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
        preferences();
}

static void hookNotification()
{
        CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(), //center
                NULL, // observer
                updatePrefs, // callback
                (CFStringRef)@"com.ashman.ClockHide.prefsUpdated",
                NULL, // object
                CFNotificationSuspensionBehaviorHold);
}

#define Hook(cls, sel, imp) \
	_ ## imp = MSHookMessage($ ## cls, @selector(sel), &$ ## imp)

MSHook(id, uiInit, SBUIController *self, SEL sel)
{
	self = _uiInit(self, sel);

	UIView* dv = [[DateView alloc] initWithFrame:CGRectMake(0, 20, 320, 20)];
	dv.backgroundColor = [UIColor clearColor];
	dv.hidden = true;
	dateView = dv;

	preferences();
	hookNotification();

	Class $SBApplication = objc_getClass("SBApplication");	
	Class $SBAwayDateView = objc_getClass("SBAwayDateView");	
	Class $TPLCDView = objc_getClass("TPLCDView");	

	Hook(SBStatusBarController, setIsLockVisible:isTimeVisible:, ch_setIsLockVisible);
	Hook(SBAwayView, middleFrame, ch_middleFrame);
	Hook(SBAwayView, initWithFrame:, awayViewInitWithFrame);
	Hook(SBAwayController, noteSyncStateChanged, noteSyncStateChanged);
	Hook(SBAwayDateView, initWithFrame:, ch_initWithFrame);
	Hook(SBAwayDateView, setIsShowingControls:, ch_setIsShowingControls);
	Hook(TPLCDView, setHidden:, setHidden);

	return self;
}

extern "C" void ClockHideInit() 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	$SBStatusBarController = objc_getClass("SBStatusBarController");	
	$SBAwayController = objc_getClass("SBAwayController");	
	$SBAwayView = objc_getClass("SBAwayView");	

	Class $SBUIController = objc_getClass("SBUIController");	
	Hook(SBUIController, init, uiInit);

	[pool release];
}
