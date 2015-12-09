#import "../RGUI.h"
#import "PrefWindowController.h"
#import "../PreferenceKeys.h"
#import "../AMPrefs/AMPreferenceWindowController.h"

@implementation PrefWindowController

- (id) init
{
	self = [super initWithAutosaveName:@"PreferencesWindow"];
	return self;
}

- (void) awakeFromNib
{
	quartzPrefPane = [[[QuartzPrefPane alloc] initWithIdentifier:@"Quartz" label:NLSC(@"PrefP-Quartz",@"Quartz preference pane") category:NLSC(@"PrefG-Views",@"Views preference group") ] autorelease];
	[self addPane:quartzPrefPane withIdentifier:[quartzPrefPane identifier]];
	
	miscPrefPane = [[[MiscPrefPane alloc] initWithIdentifier:@"Misc" label:NLSC(@"PrefP-Startup",@"Startup preference pane") category:NLSC(@"PrefG-General",@"General preference group")] autorelease];
	[self addPane:miscPrefPane withIdentifier:[miscPrefPane identifier]];
	
	colorsPrefPane = [[[ColorsPrefPane alloc] initWithIdentifier:@"Colors" label:NLSC(@"PrefP-Colors",@"Colors preference pane") category:NLSC(@"PrefG-Views",@"Views preference group")] autorelease];
	[self addPane:colorsPrefPane withIdentifier:[colorsPrefPane identifier]];
	
	syntaxColorsPrefPane = [[[SyntaxColorsPrefPane alloc] initWithIdentifier:@"Syntax Colors" label:NLSC(@"PrefP-Syntax",@"Syntax colors preference pane") category:NLSC(@"PrefG-Editor",@"Editor preference group")] autorelease];
	[self addPane:syntaxColorsPrefPane withIdentifier:[syntaxColorsPrefPane identifier]];
	
	editorPrefPane = [[[EditorPrefPane alloc] initWithIdentifier:@"Editor" label:NLSC(@"PrefP-Editor",@"Editor preference pane") category:NLSC(@"PrefG-Editor",@"Editor preference group")] autorelease];
	[self addPane:editorPrefPane withIdentifier:[editorPrefPane identifier]];

	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:RScriptEditorDefaultFont options:NSKeyValueObservingOptionNew context:NULL];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];

	// set up some configuration options
	[self setUsesConfigurationPane:YES];
	[self setSortByCategory:YES];
	// select prefs pane for display
	[self selectPaneWithIdentifier:@"All"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:RScriptEditorDefaultFont]) {
		[[editorPrefPane valueForKeyPath:@"editorFont"] setFont:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
	}
}

- (IBAction)showPrefsWindow:(id)sender
{
	[self showWindow:self];
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)sortByAlphabet:(id)sender
{
	[self setSortByCategory:NO];
	[self selectIconViewPane];
}

- (IBAction)sortByCategory:(id)sender
{
	[self setSortByCategory:YES];
	[self selectIconViewPane];
}

- (BOOL)shouldLoadPreferencePane:(NSString *)identifier
{
	//	NSLog(@"shouldLoadPreferencePane: %@", identifier);
	return YES;
}

- (void)willSelectPreferencePane:(NSString *)identifier
{
	//	NSLog(@"willSelectPreferencePane: %@", identifier);
}

- (void)didUnselectPreferencePane:(NSString *)identifier
{
	//	NSLog(@"didUnselectPreferencePane: %@", identifier);
}

- (NSString *)displayNameForCategory:(NSString *)category
{
	return category;
}

/**
 * Trap window close notifications and use them to ensure changes are saved.
 */
- (void)windowWillClose:(NSNotification *)notification
{
	[[NSColorPanel sharedColorPanel] close];
	[[NSFontPanel sharedFontPanel] close];
	
	// Mark the currently selected field in the window as having finished editing, to trigger saves.
	if ([[self window] firstResponder]) {
		[[self window] endEditingFor:[[self window] firstResponder]];
	}
}

- (void)changeFont:(id)sender
{

	if([self activePane] == (AMPreferencePane*)editorPrefPane) {

		NSFont *font;
		NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
		font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:RScriptEditorDefaultFont]]];
	
		[prefs setObject:[NSArchiver archivedDataWithRootObject:font] forKey:RScriptEditorDefaultFont];

		[[editorPrefPane valueForKeyPath:@"editorFont"] setFont:font];
	}

}


@end
