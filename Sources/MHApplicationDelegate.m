//
//  MHApplicationDelegate.m
//  MongoHub
//
//  Created by Syd on 10-4-24.
//  Copyright MusicPeace.ORG 2010 . All rights reserved.
//

#import "Configure.h"
#import "MHApplicationDelegate.h"
#import "MHConnectionWindowController.h"
#import "ConnectionsArrayController.h"
#import "ConnectionsCollectionView.h"
#import "MHConnectionEditorWindowController.h"
#import "MHConnectionStore.h"
#import "MHPreferenceController.h"
#import <Sparkle/Sparkle.h>

#define YOUR_EXTERNAL_RECORD_EXTENSION @"mgo"
#define YOUR_STORE_TYPE NSXMLStoreType

#define MHSofwareUpdateChannelKey           @"MHSofwareUpdateChannel"

@interface MHApplicationDelegate()
@property (nonatomic, strong, readwrite) MHConnectionEditorWindowController *connectionEditorWindowController;
@end

@implementation MHApplicationDelegate

@synthesize window = _window;
@synthesize connectionsCollectionView;
@synthesize connectionsArrayController;
@synthesize bundleVersion;
@synthesize preferenceController = _preferenceController;
@synthesize connectionEditorWindowController = _connectionEditorWindowController;

- (void)awakeFromNib
{
    [connectionsArrayController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"alias" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}

- (void)dealloc
{
    [_window release];
    [managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
    
    [connectionsCollectionView release];
    [connectionsArrayController release];
    
    [bundleVersion release];
    
    [super dealloc];
}

/**
    Returns the support directory for the application, used to store the Core Data
    store file.  This code uses a directory named "MongoHub" for
    the content, either in the NSApplicationSupportDirectory location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportDirectory
{

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"MongoHub"];
}

/**
    Returns the external records directory for the application.
    This code uses a directory named "MongoHub" for the content, 
    either in the ~/Library/Caches/Metadata/CoreData location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *)externalRecordsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"Metadata/CoreData/MongoHub"];
}

/**
    Creates, retains, and returns the managed object model for the application 
    by merging all of the models found in the application bundle.
 */
 
- (NSManagedObjectModel *)managedObjectModel
{
    if (managedObjectModel) {
        return managedObjectModel;
    }
    
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}


/**
    Returns the persistent store coordinator for the application.  This 
    implementation will create and return a coordinator, having added the 
    store for the application to it.  (The directory for the store is created, 
    if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator
{
    if (persistentStoreCoordinator) return persistentStoreCoordinator;

    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSAssert(NO, @"Managed object model is nil");
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupportDirectory = [self applicationSupportDirectory];
    NSError *error = nil;
    
    if (![fileManager fileExistsAtPath:applicationSupportDirectory isDirectory:NULL]) {
        if (![fileManager createDirectoryAtPath:applicationSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSAssert2(NO, @"Failed to create App Support directory %@ : %@", applicationSupportDirectory, error);
            NSLog(@"Error creating application support directory at %@ : %@",applicationSupportDirectory,error);
            return nil;
        }
    }

    NSString *externalRecordsDirectory = [self externalRecordsDirectory];
    if (![fileManager fileExistsAtPath:externalRecordsDirectory isDirectory:NULL]) {
        if (![fileManager createDirectoryAtPath:externalRecordsDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Error creating external records directory at %@ : %@",externalRecordsDirectory,error);
            NSAssert2(NO, @"Failed to create external records directory %@ : %@", externalRecordsDirectory, error);
            NSLog(@"Error creating external records directory at %@ : %@",externalRecordsDirectory,error);
            return nil;
        };
    }

    NSURL *url = [NSURL fileURLWithPath: [applicationSupportDirectory stringByAppendingPathComponent: @"storedata"]];
    // set store options to enable spotlight indexing
    NSMutableDictionary *storeOptions = [NSMutableDictionary dictionary];
    [storeOptions setObject:YOUR_EXTERNAL_RECORD_EXTENSION forKey:NSExternalRecordExtensionOption];
    [storeOptions setObject:externalRecordsDirectory forKey:NSExternalRecordsDirectoryOption];
    [storeOptions setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
    [storeOptions setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: mom];
    if (![persistentStoreCoordinator addPersistentStoreWithType:YOUR_STORE_TYPE 
                                                configuration:nil 
                                                URL:url 
                                                options:storeOptions 
                                                error:&error]){
        [[NSApplication sharedApplication] presentError:error];
        [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
        return nil;
    }    

    return persistentStoreCoordinator;
}

/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
 
- (NSManagedObjectContext *) managedObjectContext
{
    if (managedObjectContext) return managedObjectContext;

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator: coordinator];

    return managedObjectContext;
}

/**
    Returns the NSUndoManager for the application.  In this case, the manager
    returned is that of the managed object context for the application.
 */
 
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

/**
    Performs the save action for the application, which is to send the save:
    message to the application's managed object context.  Any encountered errors
    are presented to the user.
 */
 
- (void)saveConnections
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }

    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}


/**
    Implementation of the applicationShouldTerminate: method, used here to
    handle the saving of changes in the application managed object context
    before the application terminates.
 */
 
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (!managedObjectContext) return NSTerminateNow;

    if (![managedObjectContext commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }

    if (![managedObjectContext hasChanges]) return NSTerminateNow;

    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
    
        // This error handling simply presents error information in a panel with an 
        // "Ok" button, which does not include any attempt at error recovery (meaning, 
        // attempting to fix the error.)  As a result, this implementation will 
        // present the information to the user and then follow up with a panel asking 
        // if the user wishes to "Quit Anyway", without saving the changes.

        // Typically, this process should be altered to include application-specific 
        // recovery steps.  
                
        BOOL result = [sender presentError:error];
        if (result) return NSTerminateCancel;

        NSString *question = NSLocalizedString(@"Could not save changes while quitting.  Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        [alert release];
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) return NSTerminateCancel;

    }

    return NSTerminateNow;
}

/**
    Implementation of application:openFiles:, to respond to an open file request from an external record file
 */
- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)files
{
    NSString *aPath = [files lastObject]; // just an example to get at one of the paths

    if (aPath && [aPath hasSuffix:YOUR_EXTERNAL_RECORD_EXTENSION]) {
        // decode URI from path
        NSURL *objectURI = [[NSPersistentStoreCoordinator elementsDerivedFromExternalRecordURL:[NSURL fileURLWithPath:aPath]] objectForKey:NSObjectURIKey];
        if (objectURI) {
            NSManagedObjectID *moid = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:objectURI];
            if (moid) {
                    NSManagedObject *mo = [[self managedObjectContext] objectWithID:moid];
                    NSLog(@"The record for path %@ is %@",moid,mo);
                    
                    // your code to select the object in your application's UI
            }
            
        }
    }
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSString *appVersion = [[NSString alloc] initWithFormat:@"version: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    [bundleVersion setStringValue: appVersion];
    [appVersion release];
    [updater checkForUpdatesInBackground];
}

#pragma mark connections related method
- (IBAction)showAddConnectionPanel:(id)sender
{
    if (!self.connectionEditorWindowController) {
        self.connectionEditorWindowController = [[[MHConnectionEditorWindowController alloc] init] autorelease];
        self.connectionEditorWindowController.delegate = self;
        [self.connectionEditorWindowController modalForWindow:self.window];
    }
}

- (IBAction)duplicateConnection:(id)sender
{
    if ([connectionsArrayController selectedObjects] && !self.connectionEditorWindowController) {
        self.connectionEditorWindowController = [[MHConnectionEditorWindowController alloc] init];
        self.connectionEditorWindowController.delegate = self;
        self.connectionEditorWindowController.connectionStoreDefaultValue = [[connectionsArrayController selectedObjects] objectAtIndex:0];
        [self.connectionEditorWindowController modalForWindow:self.window];
    }
}

- (IBAction)deleteConnection:(id)sender
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert setMessageText:@"Delete the connection?"];
    [alert setInformativeText:@"Deleted connections cannot be restored."];
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(deleteConnectionAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)deleteConnectionAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertSecondButtonReturn) {
        [connectionsArrayController remove:self];
        [self saveConnections];
    }
}

- (IBAction)showEditConnectionPanel:(id)sender
{
    if (![connectionsArrayController selectedObjects] || self.connectionEditorWindowController) {
        return;
    }
    MHConnectionStore *connection = [[connectionsArrayController selectedObjects] objectAtIndex:0];
    
    self.connectionEditorWindowController = [[[MHConnectionEditorWindowController alloc] init] autorelease];
    self.connectionEditorWindowController.delegate = self;
    self.connectionEditorWindowController.editedConnectionStore = connection;
    [self.connectionEditorWindowController modalForWindow:self.window];
}

- (IBAction)resizeConnectionItemView:(id)sender
{
    CGFloat theSize = [sender floatValue]/100.0f*360.0f;
    [connectionsCollectionView setSubviewSize:theSize];
}

- (IBAction)showConnectionWindow:(id)sender {
    if (![connectionsArrayController selectedObjects]) {
        return;
    }
    [self doubleClick:[[connectionsArrayController selectedObjects] objectAtIndex:0]];
}

- (void)doubleClick:(id)sender
{
    if (![sender isKindOfClass:[MHConnectionStore class]]) {
        sender = [[connectionsArrayController selectedObjects] objectAtIndex:0];
    }
    if ([self isOpenedConnection:sender]) {
        return;
    }
    MHConnectionWindowController *connectionWindowController = [[MHConnectionWindowController alloc] init];
    connectionWindowController.connectionStore = sender;
    [connectionWindowController showWindow:sender];
}

- (BOOL)isOpenedConnection:(MHConnectionStore *)aConnection
{
    NSWindow *aWindow;
    for (aWindow in [[NSApplication sharedApplication] windows])
    {
        id aDelegate = [aWindow delegate];
        if ([aDelegate isKindOfClass:[MHConnectionWindowController class]] && [aDelegate connectionStore] == aConnection) {
            [aWindow makeKeyAndOrderFront:nil];
            return YES;
        }
    }
    return NO;
}

- (void)openSupportPanel:(id)sender
{
    [NSApp beginSheet:supportPanel modalForWindow:_window modalDelegate:self didEndSelector:@selector(supportPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)supportPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheet close];
}

- (IBAction)closeSupportPanel:(id)sender
{
    [NSApp endSheet:supportPanel];
}

- (IBAction)openFeatureRequestBugReport:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/fotonauts/MongoHub-Mac/issues"]];
}

- (IBAction)openConnectionWindow:(id)sender
{
    [_window makeKeyAndOrderFront:sender];
}

- (IBAction)openPreferenceWindow:(id)sender
{
    if (!_preferenceController) {
        _preferenceController = [[MHPreferenceController preferenceController] retain];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closingPreferenceController:) name:MHPreferenceControllerClosing object:_preferenceController];
    }
    [_preferenceController openWindow:sender];
}

- (void)closingPreferenceController:(NSNotification *)notification
{
    if (notification.object == _preferenceController) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:notification.object];
        [_preferenceController autorelease];
        _preferenceController = nil;
    }
}

- (MHSoftwareUpdateChannel)softwareUpdateChannel
{
    NSString *value;
    MHSoftwareUpdateChannel result = MHSoftwareUpdateChannelDefault;
    
    value = [NSUserDefaults.standardUserDefaults objectForKey:MHSofwareUpdateChannelKey];
    if ([value isEqualToString:@"beta"]) {
        result = MHSoftwareUpdateChannelBeta;
    }
    return result;
}

- (void)setSoftwareUpdateChannel:(MHSoftwareUpdateChannel)value
{
    switch (value) {
        case MHSoftwareUpdateChannelDefault:
            [NSUserDefaults.standardUserDefaults removeObjectForKey:MHSofwareUpdateChannelKey];
            break;
        
        case MHSoftwareUpdateChannelBeta:
            [NSUserDefaults.standardUserDefaults setObject:@"beta" forKey:MHSofwareUpdateChannelKey];
            break;
    }
    [NSUserDefaults.standardUserDefaults synchronize];
    [updater checkForUpdatesInBackground];
}

@end

@implementation MHApplicationDelegate (SUUpdate)

+ (NSString *)systemVersionString
{
    return [[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"];
}

+ (id)defaultComparator
{
    id comparator = [NSClassFromString(@"SUStandardVersionComparator") performSelector:@selector(defaultComparator)];
  
    NSAssert(comparator != nil, @"cannot get an instance of 'SUStandardVersionComparator'");
    return comparator;
}

- (BOOL)hostSupportsItem:(SUAppcastItem *)ui
{
    if ([ui minimumSystemVersion] == nil || [[ui minimumSystemVersion] isEqualToString:@""]) { return YES; }
    
    BOOL minimumVersionOK = TRUE;
    
    // Check minimum and maximum System Version
    if ([ui minimumSystemVersion] != nil && ![[ui minimumSystemVersion] isEqualToString:@""]) {
        minimumVersionOK = [[MHApplicationDelegate defaultComparator] compareVersion:[ui minimumSystemVersion] toVersion:[MHApplicationDelegate systemVersionString]] != NSOrderedDescending;
    }
    
    return minimumVersionOK;
}

- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)bundle
{
    SUAppcastItem *result = nil;
    BOOL shouldUseBeta = self.softwareUpdateChannel == MHSoftwareUpdateChannelBeta;
    id comparator = [MHApplicationDelegate defaultComparator];
  
    for (SUAppcastItem *item in appcast.items) {
        if ([self hostSupportsItem:item] && (shouldUseBeta || ![[item.propertiesDictionary objectForKey:@"beta"] isEqualToString:@"1"])) {
          if (result == nil) {
              result = item;
          } else if ([comparator compareVersion:result.versionString toVersion:item.versionString] != NSOrderedDescending) {
              result = item;
          }
        }
    }
    return result;
}

@end

@implementation MHApplicationDelegate(MHConnectionEditorWindowControllerDelegate)

- (void)connectionWindowControllerDidCancel:(MHConnectionEditorWindowController *)controller
{
    if (self.connectionEditorWindowController == controller) {
        self.connectionEditorWindowController = nil;
    }
}

- (void)connectionWindowControllerDidValidate:(MHConnectionEditorWindowController *)controller
{
    [self saveConnections];
    [connectionsCollectionView setNeedsDisplay:YES];
    if (self.connectionEditorWindowController == controller) {
        self.connectionEditorWindowController = nil;
    }
}

@end
