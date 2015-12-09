/* VignettesController */

#import "RGUI.h"
#import "CCComp.h"
#import "Tools/SortableDataSource.h"
#import "Tools/PDFImageView.h"
#import <Quartz/Quartz.h>


@interface VignettesController : NSObject
{
    IBOutlet NSSearchField *filterField;
    IBOutlet NSButton *openButton;
    IBOutlet NSButton *openSourceButton;
    IBOutlet NSTableView *tableView;
	IBOutlet NSWindow *window;
	IBOutlet NSDrawer *pdfDrawer;
	IBOutlet PDFImageView *pdfView;
	IBOutlet PDFView *thePDFView;
	
	SortableDataSource *dataSource;
	
	BOOL needReload;
	
	int* filter;
	int  filterlen;
}

- (IBAction)openVignette:(id)sender;
- (IBAction)openVignetteSource:(id)sender;
- (IBAction)executeSelection:(id)sender;

- (IBAction)search:(id)sender;

- (void) showVigenttes;

+ (VignettesController*) sharedController;

@end
