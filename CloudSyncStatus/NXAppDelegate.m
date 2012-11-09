//
//  NXAppDelegate.m
//  CloudSyncStatus
//
//  Created by Michael Gunder on 4/24/12.
//  Copyright (c) 2012 dot. All rights reserved.
//

#import "NXAppDelegate.h"
enum {
    CloudSyncStatusUnkown,
    CloudSyncStatusSyncing,
    CloudSyncStatusInactive
}

typedef CloudSyncStatus;

@interface NXAppDelegate() {
    NSStatusItem *_statusMenuBarItem;
}

@property (retain) NSMetadataQuery *documentStatusQuery;

@end

@implementation NXAppDelegate

@synthesize window = _window;
@synthesize documentStatusQuery = _documentStatusQuery;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [self setMenuBarIcon:CloudSyncStatusUnkown];
    
    [self ubiquitousContainerURL];
    [self ubiquitousStorageDocumentSearch];
}

- (void)setMenuBarIcon:(CloudSyncStatus)status andStatusMenuItemText:(NSString *)aString {
    if (!_statusMenuBarItem) {
        NSZone *menuZone = [NSMenu menuZone];
        NSMenu *menu = [[NSMenu allocWithZone:menuZone] init];
        
        NSMenuItem *menuItem =[[NSMenuItem alloc] initWithTitle:@"Initializing..." action:nil keyEquivalent:@""];
        [menu addItem:menuItem];
        [menuItem release];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *openMenuItem =[[NSMenuItem alloc] initWithTitle:@"Open Container Folder..." action:@selector(openContainer:) keyEquivalent:@""];
        [menu addItem:openMenuItem];
        [openMenuItem release];
        
        _statusMenuBarItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
        _statusMenuBarItem.menu = menu;
    }

    //statusItem.menu = menu;
    _statusMenuBarItem.highlightMode = YES;
    
    NSString *menuBarIconFileName;
    
    switch (status) {
        case CloudSyncStatusSyncing:
            menuBarIconFileName = @"menubar-icon-active.png";
            [self setStatusMenuItemText:@"Syncing..."];
            break;
        case CloudSyncStatusInactive:
            menuBarIconFileName = @"menubar-icon-inactive.png";
            [self setStatusMenuItemText:@"Synced"];
            break;
        case CloudSyncStatusUnkown:
        default:
            menuBarIconFileName = @"menubar-icon-unkown.png";
            [self setStatusMenuItemText:@"Initializing..."];
            break;
    }
    
    if (aString) {
        [self setStatusMenuItemText:aString];
    }
    
    _statusMenuBarItem.image = [NSImage imageNamed:menuBarIconFileName];
}

- (void)setMenuBarIcon:(CloudSyncStatus)status {
    [self setMenuBarIcon:status andStatusMenuItemText:nil];
}

- (void)setStatusMenuItemText:(NSString *)aString {
    [[_statusMenuBarItem.menu itemAtIndex:0] setTitle:aString];
}

- (NSURL *)ubiquitousContainerURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *ubiquitousContainerURL = [fileManager URLForUbiquityContainerIdentifier:nil];
    
    return ubiquitousContainerURL;
}

/*
- (void)ubiquitousContainerSyncStatusCheck:(NSNotification *)notification {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *ubiquitousContainerURL = [fileManager URLForUbiquityContainerIdentifier:nil];
    
    //NSLog(@"icloud container: %@", ubiquitousContainerURL);
    
    NSNumber *ubiquitousFolderUploadStatus = nil;
    NSError *ubiquitousFolderUploadStatusError = nil;
    
    BOOL ubiquitousFolderUploadStatusResourceSuccessfullyGathered = [[ubiquitousContainerURL URLByAppendingPathComponent:@"cloud/"] getResourceValue:&ubiquitousFolderUploadStatus forKey:NSURLUbiquitousItemIsUploadedKey error:&ubiquitousFolderUploadStatusError];
    
    NSLog(@"error: %@", ubiquitousFolderUploadStatusError);
    
    NSNumber *ubiquitousFolderDownloadStatus = nil;
    NSError *ubiquitousFolderDownloadStatusError = nil;
    
    NSLog(@"checking status for: %@", [ubiquitousContainerURL URLByAppendingPathComponent:@"cloud/"]);
    
    BOOL ubiquitousFolderDownloadStatusResourceSuccessfullyGathered = [[ubiquitousContainerURL URLByAppendingPathComponent:@"cloud/"] getResourceValue:&ubiquitousFolderDownloadStatus forKey:NSURLUbiquitousItemIsDownloadedKey error:&ubiquitousFolderDownloadStatusError];
    
    NSLog(@"error: %@", ubiquitousFolderDownloadStatusError);
    
    if (!ubiquitousFolderUploadStatusResourceSuccessfullyGathered || !ubiquitousFolderDownloadStatusResourceSuccessfullyGathered) {
        NSLog(@"information gathering failed");
    }
    
    else if (![ubiquitousFolderUploadStatus boolValue] || ![ubiquitousFolderDownloadStatus boolValue]) {
        [self displayMenuBarIcon:YES];
        NSLog(@"folder is syncing: %i %i", [ubiquitousFolderUploadStatus boolValue],[ubiquitousFolderDownloadStatus boolValue]);
    }
    
    else {
        [self displayMenuBarIcon:NO];
        NSLog(@"folder is synced");
    }
}
*/

- (void)ubiquitousStorageDocumentSearch {
    self.documentStatusQuery = [[NSMetadataQuery alloc] init];

    NSPredicate *documentsPredicate = [NSPredicate predicateWithFormat:@"%K LIKE '*'", NSMetadataItemFSNameKey];

    [self.documentStatusQuery setPredicate:documentsPredicate];
    [self.documentStatusQuery setSearchScopes:[NSArray arrayWithObject:NSMetadataQueryUbiquitousDataScope]];

    [self.documentStatusQuery startQuery];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ubiquitousDocumentStatusChanged:) name:NSMetadataQueryDidFinishGatheringNotification object:self.documentStatusQuery];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ubiquitousDocumentStatusChanged:) name:NSMetadataQueryDidUpdateNotification object:self.documentStatusQuery];
}

- (void)ubiquitousDocumentStatusChanged:(NSNotification *)notification {
    [self.documentStatusQuery disableUpdates];
    
    [self setMenuBarIcon:CloudSyncStatusUnkown];
    
    int resultCount = (int)self.documentStatusQuery.resultCount;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        for (int i = 0; i < resultCount; i++) {
            NSMetadataItem *item = [self.documentStatusQuery resultAtIndex:i];
            NSString *fileName = [item valueForAttribute:NSMetadataItemDisplayNameKey];
            
            BOOL documentUploaded = [[item valueForAttribute:NSMetadataUbiquitousItemIsUploadedKey] boolValue];
            BOOL documentDownloaded = [[item valueForAttribute:NSMetadataUbiquitousItemIsDownloadedKey] boolValue];
            
            BOOL isUploadingDocument = [[item valueForAttribute:NSMetadataUbiquitousItemIsUploadingKey] boolValue];
            BOOL isDownloadingDocument = [[item valueForAttribute:NSMetadataUbiquitousItemIsDownloadingKey] boolValue];
            
            if (!documentUploaded || !documentDownloaded) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (isUploadingDocument) {
                        NSUInteger percentUploaded = [[item valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey] integerValue];
                        NSString *statusString = [NSString stringWithFormat:@"Uploading: %@ (%li %%)...", fileName, percentUploaded];
                        [self setMenuBarIcon:CloudSyncStatusSyncing andStatusMenuItemText:statusString];
                    }
                    
                    else if (isDownloadingDocument) {
                        NSUInteger percentDownloaded = [[item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey] integerValue];
                        NSString *statusString = [NSString stringWithFormat:@"Downlading: %@ (%li %%)...", fileName, percentDownloaded];
                        [self setMenuBarIcon:CloudSyncStatusSyncing andStatusMenuItemText:statusString];
                    }
                    
                    else {
                        NSString *statusString = [@"Syncing: " stringByAppendingString:fileName];
                        [self setMenuBarIcon:CloudSyncStatusSyncing andStatusMenuItemText:statusString];
                    }
                });
                
                break;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setMenuBarIcon:CloudSyncStatusInactive];
            });
        }
    });
    
    [self.documentStatusQuery enableUpdates];
}

- (void)openContainer:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[self ubiquitousContainerURL]];
}

@end
