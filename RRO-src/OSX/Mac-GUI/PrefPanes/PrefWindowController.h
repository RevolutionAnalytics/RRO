/* PrefWindowController */

#import <Cocoa/Cocoa.h>
#import "../AMPrefs/AMPreferenceWindowController.h"
#import "QuartzPrefPane.h"
#import "MiscPrefPane.h"
#import "ColorsPrefPane.h"
#import "EditorPrefPane.h"
#import "SyntaxColorsPrefPane.h"

@interface PrefWindowController : AMPreferenceWindowController
{
	QuartzPrefPane  *quartzPrefPane;
	MiscPrefPane    *miscPrefPane;
	ColorsPrefPane  *colorsPrefPane;
	SyntaxColorsPrefPane  *syntaxColorsPrefPane;
	EditorPrefPane *editorPrefPane;	
}

- (BOOL)shouldLoadPreferencePane:(NSString *)identifier;

- (void)willSelectPreferencePane:(NSString *)identifier;
- (void)didUnselectPreferencePane:(NSString *)identifier;

- (IBAction)sortByAlphabet:(id)sender;
- (IBAction)sortByCategory:(id)sender;
- (IBAction)showPrefsWindow:(id)sender;

@end
