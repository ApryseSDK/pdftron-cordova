#import <Cordova/CDV.h>
#import "PDFTron.h"

#import <PDFNet/PDFNet.h>
#import <Tools/Tools.h>

@interface PTCordovaPluginViewController : PTDocumentViewController
{
    
}

@property (copy, nonatomic) NSString* viewerID;
@property (strong, nonatomic) UIWebView* webView;
@property (copy, nonatomic) NSString* openCommandCallbackID;
@property (strong, nonatomic) NSDictionary* displayRectFromArguments;

@end

@implementation PTCordovaPluginViewController

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGRect rect;
    
    if( self.webView && [self.navigationController.view isDescendantOfView:self.webView] )
    {
        
        if ( self.displayRectFromArguments )
        {
            NSError* error;
            
            rect = CGRectMake(((NSNumber*)self.displayRectFromArguments[@"left"]).longValue, ((NSNumber*)self.displayRectFromArguments[@"top"]).longValue, ((NSNumber*)self.displayRectFromArguments[@"width"]).longValue, ((NSNumber*)self.displayRectFromArguments[@"height"]).longValue);
            
            if( error )
            {
                NSLog(@"Error method %s line %d", __PRETTY_FUNCTION__, __LINE__);
                return;
            }
            
            self.navigationController.view.superview.frame = rect;
        }
//        else if( self.viewerID )
//        {
//            NSString *js = @"function f(){ var r = document.getElementById('%@').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();";
//            NSString *result = [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:js, self.viewerID]];
//            rect = CGRectFromString(result);
//
//            self.navigationController.view.superview.frame = rect;
//        }
    }
}

@end

@interface PDFTron () <PTDocumentViewControllerDelegate>

-(void)callJavascriptCallback:(NSString*)method;

@property (strong, nonatomic) PTCordovaPluginViewController* documentViewController;
@property (strong, nonatomic) UINavigationController* navigationController;
@property (strong, nonatomic) CDVInvokedUrlCommand* javascriptCallbackBridge;
@property (strong, nonatomic) NSString* topLeftButtonName;
@property (nonatomic) BOOL showTopLeftButton;
@property (strong, nonatomic) NSDictionary* displayRectFromArguments;

@end

@implementation PDFTron



-(void)callJavascriptCallback:(NSString*)method
{
    NSDictionary* dict = @{@"action" : method };
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.javascriptCallbackBridge.callbackId];
}

-(void)sendErrorFromException:(NSException*)exception toCallbackId:(NSString*)callbackId
{
    CDVPluginResult* exceptionResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                         messageAsString:[NSString stringWithFormat:@"%@%@", exception.name, exception.reason]];
    
    [self.commandDelegate sendPluginResult:exceptionResult callbackId:callbackId];
}

-(void)sendPluginResultOKToCallbackId:(NSString*)callbackId
{
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:callbackId];
}


- (void)topLeftButtonPressed:(UIBarButtonItem *)barButtonItem
{
    
    if( barButtonItem.tag == UIBarButtonSystemItemDone )
        [self.viewController.presentedViewController dismissViewControllerAnimated:YES completion:Nil];
    
    
    [self callJavascriptCallback:@"topLeftButtonPressed"];

}

// creates a new viewer and displays it if the 'viewer' parameter is present.
-(void)NativeViewer:(CDVInvokedUrlCommand *)command
{
    @try {
        NSDictionary* initDict = command.arguments.firstObject;
        NSString* viewerID = command.arguments.count > 1 ? command.arguments.lastObject : Nil;
        NSString* initialDocLocation = [initDict[@"initialDoc"] isEqualToString:@""] ? @"https://www.canada.ca/content/dam/cra-arc/formspubs/pbg/t1105/t1105-fill-18e.pdf" : initDict[@"initialDoc"];
        
        NSString* licenseKey = ([initDict[@"l"] isEqualToString:@""] || [initDict[@"l"] isEqualToString:@"<your-key-here>"]) ? @"" : initDict[@"l"];
        
        self.topLeftButtonName = initDict[@"topLeftButtonTitle"];
        self.displayRectFromArguments = initDict[@"boundingRect"];
        
        self.showTopLeftButton = YES;
        if( initDict[@"showTopLeftButton"] )
            self.showTopLeftButton = ((NSNumber*)initDict[@"showTopLeftButton"]).boolValue;
        
        if( command.arguments.firstObject[@"initialDoc"] )
        {
            initialDocLocation = command.arguments.firstObject[@"initialDoc"];
        }
        
        [PTPDFNet Initialize:licenseKey];
        
        self.documentViewController = [[PTCordovaPluginViewController alloc] init];
        
        self.documentViewController.delegate = self;
        
        self.documentViewController.openCommandCallbackID = command.callbackId;
        
        [self disableElementsInternal:initDict[@"disabledElements"]];
        
        [self.documentViewController openDocumentWithURL:[NSURL URLWithString:initialDocLocation]];
        
        [self.documentViewController loadViewIfNeeded];
        
        if( self.showTopLeftButton && self.topLeftButtonName )
        {
            self.documentViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.topLeftButtonName  style:UIBarButtonItemStylePlain target:self action:@selector(topLeftButtonPressed:)];
        }
        
        if( viewerID && self.displayRectFromArguments)
        {
            // show as a subview
            [self overlayDocumentViewerOnDivID:viewerID viaCommand:command];
        }
        else if( viewerID )
        {
            // present the document
            [self showDocumentViewer:command];
        }
        else
        {
            [self sendPluginResultOKToCallbackId:command.callbackId];
        }
        
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
    
}

-(void)showDocumentViewer:(CDVInvokedUrlCommand*)command
{
    @try {
        if( self.navigationController )
            [self.navigationController.view removeFromSuperview];
        
        if( self.showTopLeftButton && self.topLeftButtonName == Nil)
        {
            self.documentViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(topLeftButtonPressed:)];
            self.documentViewController.navigationItem.leftBarButtonItem.tag = UIBarButtonSystemItemDone;
        }
        
        if( self.displayRectFromArguments == Nil )
        {
            self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.documentViewController];
            [self.viewController presentViewController:self.navigationController animated:YES completion:nil];
        }
        else
        {
            [self overlayDocumentViewerOnDivID:Nil viaCommand:command];
        }
        
        [self sendPluginResultOKToCallbackId:command.callbackId];
        
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
    
}

- (void)overlayDocumentViewerOnDivID:(NSString *)viewerID viaCommand:(CDVInvokedUrlCommand*)command
{
    @try {
        self.documentViewController.viewerID = viewerID;
        self.documentViewController.displayRectFromArguments = self.displayRectFromArguments;
        
        // The PTDocumentViewController must be in a navigation controller before a document can be opened
        self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.documentViewController];
        
        CGRect rect;
        
        
        if( self.displayRectFromArguments )
        {
            NSError* error;
            
            rect = CGRectMake(((NSNumber*)self.displayRectFromArguments[@"left"]).longValue, ((NSNumber*)self.displayRectFromArguments[@"top"]).longValue, ((NSNumber*)self.displayRectFromArguments[@"width"]).longValue, ((NSNumber*)self.displayRectFromArguments[@"height"]).longValue);
            
            if( error )
            {
                NSException* exception = [NSException exceptionWithName:error.localizedDescription reason:error.localizedFailureReason userInfo:error.userInfo];
                [self sendErrorFromException:exception toCallbackId:command.callbackId];
                return;
            }
        }
//        else if( self.documentViewController.viewerID )
//        {
//            NSString *js = @"function f(){ var r = document.getElementById('%@').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();";
//            NSString *result = [(UIWebView*)self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:js, viewerID]];
//            rect = CGRectFromString(result);
//        }
        
        UIView* containerView = [[UIView alloc] initWithFrame:rect];
        containerView.clipsToBounds = YES;
        
        self.navigationController.view.frame = containerView.bounds;
        
        self.webView.scrollView.scrollEnabled = NO;
        
        [self.viewController addChildViewController:self.navigationController];
        
        self.documentViewController.webView = (UIWebView*)self.webView;
        
        [containerView addSubview:self.navigationController.view];
        
        [self.webView.scrollView addSubview:containerView];
        
        [self.navigationController didMoveToParentViewController:self.viewController];
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
    
}

-(void)disableElements:(CDVInvokedUrlCommand *)command
{
    
    @try {
        
        [self disableElementsInternal:command.arguments];
        [self sendPluginResultOKToCallbackId:command.callbackId];
        
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
    
}

-(void)disableElementsInternal:(NSArray<NSString*> *)strings
{
    
        typedef void (^HideElementBlock)(void);
        
        NSDictionary *hideElementActions = @{
                                             @"toolsButton":
                                                 ^{
                                                     self.documentViewController.annotationToolbarButtonHidden = YES;
                                                 },
                                             @"searchButton":
                                                 ^{
                                                     self.documentViewController.searchButtonHidden = YES;
                                                 },
                                             @"shareButton":
                                                 ^{
                                                     self.documentViewController.shareButtonHidden = YES;
                                                 },
                                             @"viewControlsButton":
                                                 ^{
                                                     self.documentViewController.viewerSettingsButtonHidden = YES;
                                                 },
                                             @"thumbnailsButton":
                                                 ^{
                                                     self.documentViewController.thumbnailBrowserButtonHidden = YES;
                                                 },
                                             @"listsButton":
                                                 ^{
                                                     self.documentViewController.navigationListsButtonHidden = YES;
                                                 },
                                             @"thumbnailSlider":
                                                 ^{
                                                     self.documentViewController.thumbnailSliderHidden = YES;
                                                 }
                                             };
        
        
        for(NSObject* item in strings)
        {
            if( [item isKindOfClass:[NSString class]])
            {
                HideElementBlock block = hideElementActions[item];
                if (block)
                {
                    block();
                }
            }
        }
        
        [self setToolsPermission:strings toValue:NO];
    
}

-(void)setToolsPermission:(NSArray<NSString*>*) stringsArray toValue:(BOOL)value
{
    // TODO: AnnotationCreateDistanceMeasurement
    // AnnotationCreatePerimeterMeasurement
    // AnnotationCreateAreaMeasurement

    
    for(NSObject* item in stringsArray)
    {
        if( [item isKindOfClass:[NSString class]])
        {
            NSString* string = (NSString*)item;
            
            if( [string isEqualToString:@"AnnotationEdit"] )
            {
                // multi-select not implemented
            }
            else if( [string isEqualToString:@"AnnotationCreateSticky"] || [string isEqualToString:@"stickyToolButton"] )
            {
                self.documentViewController.toolManager.textAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateFreeHand"] || [string isEqualToString:@"freeHandToolButton"] )
            {
                self.documentViewController.toolManager.inkAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"TextSelect"] )
            {
                self.documentViewController.toolManager.textSelectionEnabled = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateTextHighlight"] || [string isEqualToString:@"highlightToolButton"] )
            {
                self.documentViewController.toolManager.highlightAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateTextUnderline"] || [string isEqualToString:@"underlineToolButton"] )
            {
                self.documentViewController.toolManager.underlineAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateTextSquiggly"] || [string isEqualToString:@"squigglyToolButton"] )
            {
                self.documentViewController.toolManager.squigglyAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateTextStrikeout"] || [string isEqualToString:@"strikeoutToolButton"] )
            {
                self.documentViewController.toolManager.strikeOutAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateFreeText"] || [string isEqualToString:@"freeTextToolButton"] )
            {
                self.documentViewController.toolManager.freeTextAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateCallout"] || [string isEqualToString:@"calloutToolButton"] )
            {
                // not supported
            }
            else if ( [string isEqualToString:@"AnnotationCreateSignature"] || [string isEqualToString:@"signatureToolButton"] )
            {
                self.documentViewController.toolManager.signatureAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateLine"] || [string isEqualToString:@"lineToolButton"] )
            {
                self.documentViewController.toolManager.lineAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateArrow"] || [string isEqualToString:@"arrowToolButton"] )
            {
                self.documentViewController.toolManager.arrowAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreatePolyline"] || [string isEqualToString:@"polylineToolButton"] )
            {
                self.documentViewController.toolManager.polylineAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateStamp"] || [string isEqualToString:@"stampToolButton"] )
            {
                self.documentViewController.toolManager.stampAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateRectangle"] || [string isEqualToString:@"rectangleToolButton"] )
            {
                self.documentViewController.toolManager.squareAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreateEllipse"] || [string isEqualToString:@"ellipseToolButton"] )
            {
                self.documentViewController.toolManager.circleAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreatePolygon"] || [string isEqualToString:@"polygonToolButton"] )
            {
                self.documentViewController.toolManager.polygonAnnotationOptions.canCreate = value;
            }
            else if ( [string isEqualToString:@"AnnotationCreatePolygonCloud"] || [string isEqualToString:@"cloudToolButton"] )
            {
                self.documentViewController.toolManager.cloudyAnnotationOptions.canCreate = value;
            }
    
        }
    }
}

-(void)enableTools:(CDVInvokedUrlCommand*)command
{
    NSArray* strings = command.arguments;
    @try
    {
        [self setToolsPermission:strings toValue:YES];
        [self sendPluginResultOKToCallbackId:command.callbackId];
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
}

-(void)disableTools:(CDVInvokedUrlCommand*)command
{
    NSArray* strings = command.arguments;
    @try
    {
        [self setToolsPermission:strings toValue:NO];
        [self sendPluginResultOKToCallbackId:command.callbackId];
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
}

-(void)setToolMode:(CDVInvokedUrlCommand*)command
{
    
    @try {
        
        NSArray* stringsArray = command.arguments;

        
        typedef void (^SetToolBlock)(void);
        
        
        NSDictionary *setToolActions = @{
                                         @"AnnotationCreateSticky":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTStickyNoteCreate class]];
                                             },
                                         @"AnnotationCreateFreeHand":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTFreeHandCreate class]];
                                             },
                                         @"AnnotationEdit":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTAnnotEditTool class]];
                                             },
                                         @"Pan":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTPanTool class]];
                                             },
                                         @"AnnotationCreateTextHighlight":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTTextHighlightCreate class]];
                                             },
                                         @"AnnotationCreateTextUnderline":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTTextUnderlineCreate class]];
                                             },
                                         @"AnnotationCreateTextSquiggly":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTTextSquigglyCreate class]];
                                             },
                                         @"AnnotationCreateTextStrikeout":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTTextStrikeoutCreate class]];
                                             },
                                         @"AnnotationCreateFreeText":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTFreeTextCreate class]];
                                             },
                                         @"AnnotationCreateCallout":
                                             ^{
                                                 // not supported
                                             },
                                         @"AnnotationCreateSignature":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTDigitalSignatureTool class]];
                                             },
                                         @"AnnotationCreateLine":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTLineCreate class]];
                                             },
                                         @"AnnotationCreateArrow":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTArrowCreate class]];
                                             },
                                         @"AnnotationCreatePolyline":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTPolylineCreate class]];
                                             },
                                         @"AnnotationCreateStamp":
                                             ^{
                                                 // not supported (coming soon)
                                             },
                                         @"AnnotationCreateRectangle":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTRectangleCreate class]];
                                             },
                                         @"AnnotationCreateEllipse":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTEllipseCreate class]];
                                             },
                                         @"AnnotationCreatePolygon":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTPolygonCreate class]];
                                             },
                                         @"AnnotationCreatePolygonCloud":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTCloudCreate class]];
                                             },
                                         @"AnnotationCreateDistanceMeasurement":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTRulerCreate class]];
                                             },
                                         @"AnnotationCreatePerimeterMeasurement":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTPerimeterCreate class]];
                                             },
                                         @"AnnotationCreateAreaMeasurement":
                                             ^{
                                                 [self.documentViewController.toolManager changeTool:[PTAreaCreate class]];
                                             }
                                         };
        
        
        for(NSObject* item in stringsArray)
        {
            if( [item isKindOfClass:[NSString class]])
            {
                SetToolBlock block = setToolActions[item];
                if (block)
                {
                    block();
                }
            }
        }
        
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    } @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
}

-(void)messageChannel:(CDVInvokedUrlCommand*)command
{
    self.javascriptCallbackBridge = command;
}

-(void)loadDocument:(CDVInvokedUrlCommand *)command
{
    @try
    {
        NSString* urlString = command.arguments.firstObject;
        NSURL* url = [NSURL URLWithString:urlString];
        
        self.documentViewController.openCommandCallbackID = command.callbackId;
        [self.documentViewController openDocumentWithURL:url];
    }
    @catch (NSException *exception) {
        [self sendErrorFromException:exception toCallbackId:command.callbackId];
    }
}


#pragma PTDocumentViewControllerDelegate

-(void)documentViewControllerDidOpenDocument:(PTDocumentViewController *)documentViewController
{
    if( self.documentViewController.openCommandCallbackID )
    {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:self.documentViewController.openCommandCallbackID];
    }
}

-(void)documentViewController:(PTDocumentViewController *)documentViewController didFailToOpenDocumentWithError:(NSError *)error
{
    NSException* exception = [NSException exceptionWithName:error.localizedDescription reason:error.localizedFailureReason userInfo:error.userInfo];
    
    if( self.documentViewController.openCommandCallbackID )
    {
        [self sendErrorFromException:exception toCallbackId:self.documentViewController.openCommandCallbackID];
    }
}


- (BOOL)isVirtual
{
#if TARGET_OS_SIMULATOR
    return true;
#elif TARGET_IPHONE_SIMULATOR
    return true;
#else
    return false;
#endif
}




@end
