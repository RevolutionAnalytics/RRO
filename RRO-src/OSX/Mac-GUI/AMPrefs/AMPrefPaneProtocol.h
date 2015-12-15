//
//  AMPrefPaneProtocol.h
//  PrefsPane
//
//  Created by Andreas on Wed Jun 04 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import <AppKit/NSView.h>

// important keys for bundle's info dictionary
// from NSPreferencePane:
// - CFBundleIdentifier
// - NSMainNibFile
// - NSPrefPaneIconFile
// - NSPrefPaneIconLabel
// - NSPrincipalClass
#define CFBundleIdentifierKey @"CFBundleIdentifier"
#define NSMainNibFileKey @"NSMainNibFile"
#define NSPrefPaneIconFileKey @"NSPrefPaneIconFile"
#define NSPrefPaneIconLabelKey @"NSPrefPaneIconLabel"
#define NSPrincipalClassKey @"NSPrincipalClass"
// additional:
#define AMPrefPaneCategoryKey @"AMPrefPaneCategory"
#define AMPrefPaneVersionKey @"AMPrefPaneVersion"

typedef enum AMPreferencePaneUnselectReply
{
	AMUnselectCancel = 0,
	AMUnselectNow = 1,
	AMUnselectLater = 2
} AMPreferencePaneUnselectReply;


@protocol AMPrefPaneProtocol
- (NSString *)identifier;
- (NSView *)mainView;
- (NSString *)label;
- (NSImage *)icon;
- (NSString *)category;
@end

@protocol AMPrefPaneBundleProtocol
- (id)initWithBundle:(NSBundle *)theBundle;
- (NSBundle *)bundle;
- (NSView *)loadMainView;
- (NSView *)mainView;
@end

@interface NSObject (AMPrefPaneInformalProtocol)
	//	Selecting the preference pane
- (void)willSelect;
- (void)didSelect;
	//	Deselecting the preference pane
- (int)shouldUnselect;
	// should be NSPreferencePaneUnselectReply
- (void)willUnselect;
- (void)didUnselect;
	// localized category name
- (NSString *)categoryDisplayName;
	// version information - "1.0" or such
- (NSString *)version;
@end
