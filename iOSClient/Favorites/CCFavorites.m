//
//  CCFavorites.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 16/01/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCFavorites.h"
#import "AppDelegate.h"
#import "CCSynchronize.h"

#import "NCBridgeSwift.h"

@interface CCFavorites () <CCActionsDeleteDelegate, CCActionsSettingFavoriteDelegate>
{
    AppDelegate *appDelegate;

    NSArray *_dataSource;
    BOOL _reloadDataSource;
    
    // Automatic Upload Folder
    NSString *_autoUploadFileName;
    NSString *_autoUploadDirectory;
}
@end

@implementation CCFavorites

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        appDelegate.activeFavorites = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];

    // dataSource
    _dataSource = [NSMutableArray new];
    
    // Metadata
    _metadata = [tableMetadata new];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 1)];
    self.tableView.separatorColor = [NCBrandColor sharedInstance].seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.delegate = self;
    
    // calculate _serverUrl
    if (!_serverUrl)
        _serverUrl = nil;
  
    // Title
    if (_titleViewControl)
        self.title = _titleViewControl;
    else
        self.title = NSLocalizedString(@"_favorites_", nil);
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    [appDelegate aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [appDelegate plusButtonVisibile:true];
    
    [self reloadDatasource];
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Active Main
    appDelegate.activeFavorites = self;
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [appDelegate changeTheming:self];
    
    // Reload Table View
    [self.tableView reloadData];
}

- (void)triggerProgressTask:(NSNotification *)notification
{
    //NSDictionary *dict = notification.userInfo;
    //float progress = [[dict valueForKey:@"progress"] floatValue];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [NCBrandColor sharedInstance].backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favoriteNoFiles"] multiplier:2 color:[NCBrandColor sharedInstance].yellowFavorite];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_favorite_no_files_", nil)];
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_tutorial_favorite_view_", nil)];
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete <delegate> =====
#pragma--------------------------------------------------------------------------------------------

- (void)deleteFileOrFolderSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if (errorCode == 0)
        [self reloadDatasource];
    else
        NSLog(@"[LOG] DeleteFileOrFolder failure error %d, %@", (int)errorCode, message);
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Favorite <delegate> =====
#pragma--------------------------------------------------------------------------------------------

- (void)settingFavoriteSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if (errorCode == 0) {
        
        [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadataNet.fileID favorite:[metadataNet.optionAny boolValue]];
        [self reloadDatasource];
        
    } else {
        
         NSLog(@"[LOG] Setting Favorite failure error %d, %@", (int)errorCode, message);
    }
}

- (void)addFavoriteFolder:(NSString *)serverUrl
{
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    if (!directoryID) return;
    
    NSString *selector;
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.depth = @"1";
    metadataNet.directoryID = directoryID;
    
    if ([CCUtility getFavoriteOffline])
        selector = selectorReadFolderWithDownload;
    else
        selector = selectorReadFolder;
    
    metadataNet.selector = selector;
    metadataNet.serverUrl = serverUrl;
    
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:[CCSynchronize sharedSynchronize] metadataNet:metadataNet];
}

- (void)listingFavoritesSuccessFailure:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    if (errorCode == 0) {
    
        NSString *father = @"";
        NSMutableArray *filesEtag = [NSMutableArray new];
        
        for (tableMetadata *metadata in metadatas) {
            
            // insert for test NOT favorite
            [filesEtag addObject:metadata.fileID];
            
            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
            NSString *serverUrlSon = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName];
            
            if (![serverUrlSon containsString:father]) {
                
                if (metadata.directory) {
                    
                    if ([CCUtility getFavoriteOffline])
                        [[CCSynchronize sharedSynchronize] readFileForFolder:metadata.fileName serverUrl:serverUrl selector:selectorReadFileFolderWithDownload];
                    else
                        [[CCSynchronize sharedSynchronize] readFileForFolder:metadata.fileName serverUrl:serverUrl selector:selectorReadFileFolder];

                } else {
                    
                    if ([CCUtility getFavoriteOffline])
                        [[CCSynchronize sharedSynchronize] readFile:metadata selector:selectorReadFileWithDownload];
                    else
                        [[CCSynchronize sharedSynchronize] readFile:metadata selector:selectorReadFile];
                }
                
                father = serverUrlSon;
            }
        }
        
        // Verify remove favorite
        NSArray *allRecordFavorite = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND favorite == true", appDelegate.activeAccount] sorted:nil ascending:NO];
        
        for (tableMetadata *metadata in allRecordFavorite)
            if (![filesEtag containsObject:metadata.fileID])
                [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadata.fileID favorite:NO];
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
    
    } else {
        
        NSLog(@"[LOG] Listing Favorites failure error %d, %@", (int)errorCode, message);
    }
}

- (void)listingFavorites
{
    // test
    if (appDelegate.activeAccount.length == 0)
        return;
    
    [[CCActions sharedInstance] listingFavorites:@"" delegate:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccessFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Check Active Account
    if (![metadataNet.account isEqualToString:appDelegate.activeAccount])
        return;
    
    [self reloadDatasource];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadStart:(NSString *)fileID account:(NSString *)account task:(NSURLSessionDownloadTask *)task serverUrl:(NSString *)serverUrl
{
    [self reloadDatasource];
        
    [appDelegate updateApplicationIconBadgeNumber];
}

- (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode
{
    if (errorCode == 0) {
        
        _metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
        
        if ([_metadata.typeFile isEqualToString: k_metadataTypeFile_compress]) {
            
            [self openWith:_metadata];
            
        } else if ([_metadata.typeFile isEqualToString: k_metadataTypeFile_unknown]) {
            
            [self openWith:_metadata];
            
        } else {
            
            if ([self shouldPerformSegue])
                [self performSegueWithIdentifier:@"segueDetail" sender:self];
        }
        
    } else {
        
        if (errorCode != k_CCErrorFileAlreadyInDownload)
            [appDelegate messageNotification:@"_download_file_" description:errorMessage visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    }
}

- (void)openWith:(tableMetadata *)metadata
{
    if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
        
        NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView]];
        
        _docController = [UIDocumentInteractionController interactionControllerWithURL:url];
        _docController.delegate = self;
        
        [_docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
    }
}


- (void)tapActionConnectionMounted:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];

    if (metadata)
        [appDelegate.activeMain openWindowShare:metadata];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== menu action : Favorite, More, Delete [swipe] =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)canOpenMenuAction:(tableMetadata *)metadata
{
    return YES;
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
    
    return [self canOpenMenuAction:metadata];
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        [self actionDelete:indexPath];
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        
        tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
        [[CCActions sharedInstance] settingFavorite:metadata favorite:NO delegate:self];
    }
    
    return YES;
}

- (void)actionDelete:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        [[CCActions sharedInstance] deleteFileOrFolder:metadata delegate:self hud:nil hudTitled:nil];
        [self reloadDatasource];
    }]];
    
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)actionMore:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint touch = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touch];
    UIImage *iconHeader;
    
    tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
    
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.tabBarController.view title:nil];
    
    actionSheet.animationDuration = 0.2;
    
    actionSheet.buttonHeight = 50.0;
    actionSheet.cancelButtonHeight = 50.0f;
    actionSheet.separatorHeight = 5.0f;
    
    actionSheet.automaticallyTintButtonImages = @(NO);
    
    actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].encrypted };
    actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor blackColor] };
    actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName:[UIColor blackColor] };
    actionSheet.disableButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor darkGrayColor] };
    
    actionSheet.separatorColor = [NCBrandColor sharedInstance].seperator;
    actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);
    
    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]]) {
        
        iconHeader = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]];
        
    } else {
        
        if (metadata.directory)
            iconHeader = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
        else
            iconHeader = [UIImage imageNamed:metadata.iconName];
    }
    
    [actionSheet addButtonWithTitle: metadata.fileNameView image: iconHeader backgroundColor: [NCBrandColor sharedInstance].tabBar height: 50.0 type: AHKActionSheetButtonTypeDisabled handler: nil
     ];
    
    // Share
    [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"share"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement] backgroundColor:[NCBrandColor sharedInstance].backgroundView height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
        
        [appDelegate.activeMain openWindowShare:metadata];
    }];
    
    // NO Directory
    if (metadata.directory == NO) {
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_open_in_", nil) image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"openFile"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement] backgroundColor:[NCBrandColor sharedInstance].backgroundView height: 50.0 type:AHKActionSheetButtonTypeDefault handler:^(AHKActionSheet *as) {
            [self.tableView setEditing:NO animated:YES];
            [self openWith:metadata];
        }];
    }
    
    [actionSheet show];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (tableMetadata *)setSelfMetadataFromIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [_dataSource objectAtIndex:indexPath.row];
    
    return metadata;
}

- (void)readFolder:(NSString *)serverUrl
{
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    NSMutableArray *metadatas = [NSMutableArray new];
    NSArray *recordsTableMetadata ;
    
    NSString *sorted = [CCUtility getOrderSettings];
    if ([sorted isEqualToString:@"fileName"])
        sorted = @"fileName";
        
    if (!_serverUrl) {
        
        recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND favorite == true", appDelegate.activeAccount] sorted:sorted ascending:[CCUtility getAscendingSettings]];
            
    } else {
        
        NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];        
        
        if (directoryID)
            recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"directoryID == %@", directoryID] sorted:sorted ascending:[CCUtility getAscendingSettings]];
    }
        
    CCSectionDataSourceMetadata *sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:nil activeAccount:appDelegate.activeAccount];
        
    NSArray *fileIDs = [sectionDataSource.sectionArrayRow objectForKey:@"_none_"];
    for (NSString *fileID in fileIDs)
        [metadatas addObject:[sectionDataSource.allRecordsDataSource objectForKey:fileID]];
        
    _dataSource = [NSArray arrayWithArray:metadatas];
    
    // get auto upload folder
    _autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    _autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:appDelegate.activeUrl];
    
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CCCellMain *cell = (CCCellMain *)[tableView dequeueReusableCellWithIdentifier:@"CellMain" forIndexPath:indexPath];
    tableMetadata *metadata;
    
    // variable base
    cell.delegate = self;
    
    // separator
    cell.separatorInset = UIEdgeInsetsMake(0.f, 60.f, 0.f, 0.f);
    
    // Initialize
    cell.status.image = nil;
    cell.favorite.image = nil;
    cell.local.image = nil;
    cell.shared.image = nil;
        
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    cell.selectedBackgroundView = selectionColor;
    
    metadata = [_dataSource objectAtIndex:indexPath.row];
        
    // favorite
    if (_serverUrl == nil)
        cell.favorite.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] multiplier:2 color:[NCBrandColor sharedInstance].yellowFavorite];
    
    cell.labelTitle.textColor = [UIColor blackColor];
    
    // filename
    cell.labelTitle.text = metadata.fileNameView;
    cell.labelInfoFile.text = @"";
    
    // Shared
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (!serverUrl)
        return cell;
    NSString *shareLink = [appDelegate.sharesLink objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];
    NSString *shareUserAndGroup = [appDelegate.sharesUserAndGroup objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];

    // Immage
    if (metadata.directory) {
            
        if (metadata.e2eEncrypted) {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderEncrypted"] multiplier:3 color:[NCBrandColor sharedInstance].brandElement];
        } else if ([metadata.fileName isEqualToString:_autoUploadFileName] && [self.serverUrl isEqualToString:_autoUploadDirectory]) {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderPhotos"] multiplier:3 color:[NCBrandColor sharedInstance].brandElement];
        } else if ([shareLink length] > 0) {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_public"] multiplier:3 color:[NCBrandColor sharedInstance].brandElement];
        } else if ([shareUserAndGroup length] > 0) {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_shared_with_me"] multiplier:3 color:[NCBrandColor sharedInstance].brandElement];
        } else {
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:3 color:[NCBrandColor sharedInstance].brandElement];
        }
            
    } else {
            
        if ([shareLink length] > 0 || [shareUserAndGroup length] > 0) {
            
            if ([shareLink length] > 0)
                cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"sharebylink"] multiplier:2 color:[NCBrandColor sharedInstance].gray];
            else
                cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"share"] multiplier:2 color:[NCBrandColor sharedInstance].gray];
                
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionConnectionMounted:)];
            [tap setNumberOfTapsRequired:1];
            cell.shared.userInteractionEnabled = YES;
            [cell.shared addGestureRecognizer:tap];
        }
        
        cell.file.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]];
        
        if (cell.file.image == nil) {
            
            cell.file.image = [UIImage imageNamed:metadata.iconName];
            
            if (metadata.thumbnailExists)
                [[CCActions sharedInstance] downloadTumbnail:metadata delegate:self];
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // E2EE Image Status Encrypted
        // ----------------------------------------------------------------------------------------------------------
        
        tableE2eEncryption *tableE2eEncryption = [[NCManageDatabase sharedInstance] getE2eEncryptionWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND fileNameIdentifier == %@", appDelegate.activeAccount, metadata.fileName]];
        if (tableE2eEncryption)
            cell.status.image = [UIImage imageNamed:@"encrypted"];
    }
    
    // text and length
    if (metadata.directory) {
        
        cell.labelInfoFile.text = [CCUtility dateDiff:metadata.date];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
    } else {
        
        NSString *date = [CCUtility dateDiff:metadata.date];
        NSString *length = [CCUtility transformedSize:metadata.size];
        
        if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView])
            cell.local.image = [UIImage imageNamed:@"local"];
        else
            cell.local.image = nil;
            
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ %@", date, length];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // swipe
    // ----------------------------------------------------------------------------------------------------------
    
    // LEFT : configure ONLY Root Favorites : Remove file/folder Favorites
    if (_serverUrl == nil) {
        
        cell.leftButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] multiplier:2 color:[UIColor whiteColor]] backgroundColor:[NCBrandColor sharedInstance].yellowFavorite padding:25]];
        cell.leftExpansion.buttonIndex = 0;
        cell.leftExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *favoriteButton = (MGSwipeButton *)[cell.leftButtons objectAtIndex:0];
        [favoriteButton centerIconOverText];
    }
    
    
    // RIGHT
    cell.rightButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"delete"] multiplier:2 color:[UIColor whiteColor]] backgroundColor:[UIColor redColor] padding:25]];
    
    cell.rightExpansion.buttonIndex = 0;
    cell.rightExpansion.fillOnTrigger = NO;
    
    //centerIconOverText
    MGSwipeButton *deleteButton = (MGSwipeButton *)[cell.rightButtons objectAtIndex:0];
    [deleteButton centerIconOverText];

    // ----------------------------------------------------------------------------------------------------------
    // more
    // ----------------------------------------------------------------------------------------------------------
    
    cell.more.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"more"] multiplier:2 color:[NCBrandColor sharedInstance].gray];
    
    if ([self canOpenMenuAction:metadata]) {
        
        UITapGestureRecognizer *tapMore = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionMore:)];
        [tapMore setNumberOfTapsRequired:1];
        cell.more.userInteractionEnabled = YES;
        [cell.more addGestureRecognizer:tapMore];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    _metadata = [self setSelfMetadataFromIndexPath:indexPath];
    
    // if is in download [do not touch]
    if (_metadata.status == k_metadataStatusWaitDownload || _metadata.status == k_metadataStatusInDownload || _metadata.status == k_metadataStatusDownloading)
        return;
    
    // File
    if (_metadata.directory == NO) {
        
        // File do not exists
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];

        if (serverUrl) {
            
            if ([CCUtility fileProviderStorageExists:_metadata.fileID fileName:_metadata.fileNameView]) {
            
                [self downloadFileSuccessFailure:_metadata.fileName fileID:_metadata.fileID serverUrl:serverUrl selector:selectorLoadFileView errorMessage:@"" errorCode:0];
                            
            } else {
            
                _metadata.session = k_download_session;
                _metadata.sessionError = @"";
                _metadata.sessionSelector = selectorLoadFileView;
                _metadata.status = k_metadataStatusWaitDownload;
                
                // Add Metadata for Download
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] addMetadata:_metadata];
                [[CCNetworking sharedNetworking] downloadFile:metadata taskStatus:k_taskStatusResume delegate:self];
            }
        }
    }
    
    // Directory
    if (_metadata.directory)
        [self performSegueDirectoryWithControlPasscode];
}

-(void)performSegueDirectoryWithControlPasscode
{
    CCFavorites *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCFavorites"];
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    if (serverUrl) {
        
        vc.serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileName];
        vc.titleViewControl = _metadata.fileNameView;
    
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    // if i am in background -> exit
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    // if i am not window -> exit
    if (self.view.window == NO)
        return NO;
    
    // Collapsed but i am in detail -> exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window) return NO;
    
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id viewController = segue.destinationViewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = viewController;
        _detailViewController = (CCDetail *)nav.topViewController;
    } else {
        _detailViewController = segue.destinationViewController;
    }
    
    NSMutableArray *allRecordsDataSourceImagesVideos = [NSMutableArray new];
    
    for (tableMetadata *metadata in _dataSource) {
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])
            [allRecordsDataSourceImagesVideos addObject:metadata];
    }
    
    _detailViewController.metadataDetail = _metadata;
    _detailViewController.dateFilterQuery = nil;
    _detailViewController.dataSourceImagesVideos = allRecordsDataSourceImagesVideos;
    
    [_detailViewController setTitle:_metadata.fileNameView];
}

@end
