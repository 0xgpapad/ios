//
//  NCMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import Foundation
import FastScroll

class NCMedia: UIViewController, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, NCSelectDelegate {
    
    @IBOutlet weak var collectionView : FastScrollCollectionView!
    
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var sectionDatasource = CCSectionDataSourceMetadata()

    private var metadataPush: tableMetadata?
    private var isEditMode = false
    private var selectocId = [String]()
    
    private var filterTypeFileImage = false;
    private var filterTypeFileVideo = false;
        
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private var gridLayout: NCGridMediaLayout!
        
    private let sectionHeaderHeight: CGFloat = 50
    private let footerHeight: CGFloat = 50
    
    private var stepImageWidth: CGFloat = 10
    
    private var isDistantPast = false

    private let refreshControl = UIRefreshControl()
    private var loadingSearch = false

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeMedia = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(touchUpInsideMenuButtonMore))
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: CCGraphics.changeThemingColorImage(UIImage(named: "grid"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(touchUpInsideMenuButtonSwitch))

        // Cell
        collectionView.register(UINib.init(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionMediaHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        gridLayout = NCGridMediaLayout()
        gridLayout.preferenceWidth = CGFloat(CCUtility.getMediaWidthImage())
        gridLayout.sectionHeadersPinToVisibleBounds = true

        collectionView.collectionViewLayout = gridLayout

        // Add Refresh Control
        collectionView.refreshControl = refreshControl
        
        // empty Data Source
        collectionView.emptyDataSetDelegate = self
        collectionView.emptyDataSetSource = self
        
        // 3D Touch peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        
        // changeTheming
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure Refresh Control
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brand
        refreshControl.addTarget(self, action: #selector(loadNetworkDatasource), for: .valueChanged)
        
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(appDelegate.activeUrl)
        
        // Title
        self.navigationItem.title = NSLocalizedString("_media_", comment: "")
        
        // Fast Scrool
        configFastScroll()

        // Reload Data Source
        self.reloadDataSource(loadNetworkDatasource: true) { }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        collectionView?.reloadDataThenPerform {
            self.selectSearchSections()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.reloadDataThenPerform {
                self.downloadThumbnail()
            }
        }
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
    }

    @objc func deleteFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    self.reloadDataSource(loadNetworkDatasource: false) {
                    
                        let userInfo: [String : Any] = ["metadata": metadata, "type": "delete"]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    self.reloadDataSource(loadNetworkDatasource: false) {
                    
                        let userInfo: [String : Any] = ["metadata": metadata, "metadataNew": metadataNew, "type": "move"]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    self.reloadDataSource(loadNetworkDatasource: false) {
                    
                        let userInfo: [String : Any] = ["metadata": metadata, "metadataNew": metadataNew, "type": "rename"]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "media"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        
        var text = "\n" + NSLocalizedString("_tutorial_photo_view_", comment: "")

        if loadingSearch {
            text = "\n" + NSLocalizedString("_search_in_progress_", comment: "")
        }
        
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: IBAction
    
    @objc func touchUpInsideMenuButtonSwitch(_ sender: Any) {
        
        let itemSizeStart = self.gridLayout.itemSize
        
        UIView.animate(withDuration: 0.0, animations: {
            
            if self.gridLayout.numItems == 1 && self.stepImageWidth > 0 {
                self.stepImageWidth = -10
            } else if itemSizeStart.width < 50 {
                self.stepImageWidth = 10
            }
            
            repeat {
                self.gridLayout.preferenceWidth = self.gridLayout.preferenceWidth + self.stepImageWidth
            } while (self.gridLayout.itemSize == itemSizeStart)
            
            CCUtility.setMediaWidthImage(Int(self.gridLayout?.preferenceWidth ?? 80))
            self.collectionView.collectionViewLayout.invalidateLayout()
            
            if self.stepImageWidth < 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.selectSearchSections()
                }
            }
        })
    }
    
    @objc func touchUpInsideMenuButtonMore(_ sender: Any) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        var actions = [NCMenuAction]()

        if !isEditMode {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.isEditMode = true
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_media_folder_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "folderAutomaticUpload"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.selectStartDirectoryPhotosTab()
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: filterTypeFileImage ? "imageno" : "imageyes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.filterTypeFileImage = !self.filterTypeFileImage
                        self.reloadDataSource(loadNetworkDatasource: false) { }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: filterTypeFileVideo ? "videono" : "videoyes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.filterTypeFileVideo = !self.filterTypeFileVideo
                        self.reloadDataSource(loadNetworkDatasource: false) { }
                    }
                )
            )

        } else {
           
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_delete_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        self.deleteItems()
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_cancel_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "cancel"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.isEditMode = false
                        self.selectocId.removeAll()
                        self.collectionView?.reloadDataThenPerform {
                            self.downloadThumbnail()
                        }
                    }
                )
            )
        }

        mainMenuViewController.actions = actions
        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
    
    // MARK: Select Directory
    
    func selectStartDirectoryPhotosTab() {
        
        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let viewController = navigationController.topViewController as! NCSelect
        
        viewController.delegate = self
        viewController.hideButtonCreateFolder = true
        viewController.includeDirectoryE2EEncryption = false
        viewController.includeImages = false
        viewController.layoutViewSelect = k_layout_view_move
        viewController.selectFile = false
        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
        viewController.type = "mediaFolder"
        
        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.present(navigationController, animated: true, completion: nil)
        
    }
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String) {
        
        let oldStartDirectoryMediaTabView = NCManageDatabase.sharedInstance.getAccountStartDirectoryMediaTabView(CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl))
        
        if serverUrl != nil && serverUrl != oldStartDirectoryMediaTabView {
            
            // Save Start Directory
            NCManageDatabase.sharedInstance.setAccountStartDirectoryMediaTabView(serverUrl!)
            //
            NCManageDatabase.sharedInstance.clearTable(tableMedia.self, account: appDelegate.activeAccount)
            self.sectionDatasource = CCSectionDataSourceMetadata()
            //
            loadNetworkDatasource()
        }
    }
    
    // MARK: SEGUE
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let photoDataSource: NSMutableArray = []
        
        for ocId: String in sectionDatasource.allOcId as! [String] {
            let metadata = sectionDatasource.allRecordsDataSource.object(forKey: ocId) as! tableMetadata
            if metadata.typeFile == k_metadataTypeFile_image {
                photoDataSource.add(metadata)
            }
        }
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
            
                segueViewController.metadata = metadataPush
                segueViewController.metadatas = sectionDatasource.metadatas as! [tableMetadata]
                segueViewController.mediaFilterImage = true
            }
        }
    }
}

// MARK: - 3D Touch peek and pop

extension NCMedia: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let point = collectionView?.convert(location, from: collectionView?.superview) else { return nil }
        guard let indexPath = collectionView?.indexPathForItem(at: point) else { return nil }
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else { return nil }
        guard let cell = collectionView?.cellForItem(at: indexPath) as? NCGridMediaCell  else { return nil }
        guard let viewController = UIStoryboard(name: "CCPeekPop", bundle: nil).instantiateViewController(withIdentifier: "PeekPopImagePreview") as? CCPeekPop else { return nil }
        
        previewingContext.sourceRect = cell.frame
        viewController.metadata = metadata
        viewController.imageFile = cell.imageItem.image
        viewController.showOpenIn = true
        viewController.showShare = false
        viewController.showOpenInternalViewer = false

        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        
        guard let indexPath = collectionView?.indexPathForItem(at: previewingContext.sourceRect.origin) else { return }
        
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return
        }
        metadataPush = metadata
        
        if isEditMode {
            if let index = selectocId.firstIndex(of: metadata.ocId) {
                selectocId.remove(at: index)
            } else {
                selectocId.append(metadata.ocId)
            }
            if indexPath.section <  collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) {
                collectionView.reloadItems(at: [indexPath])
            }
            
            return
        }
        
        performSegue(withIdentifier: "segueDetail", sender: self)
    }
}

extension NCMedia: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionMediaHeader
            
            header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
            header.labelSection.textColor = .white
            header.labelHeightConstraint.constant = 20
            header.labelSection.layer.cornerRadius = 10
            header.labelSection.layer.backgroundColor = UIColor(red: 152.0/255.0, green: 167.0/255.0, blue: 181.0/255.0, alpha: 0.8).cgColor
            let width = header.labelSection.intrinsicContentSize.width + 30
            let leading = collectionView.bounds.width / 2 - width / 2
            header.labelWidthConstraint.constant = width
            header.labelLeadingConstraint.constant = leading
            
            return header
            
        } else {
            
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            
            footer.setTitleLabel(sectionDatasource: sectionDatasource)
            
            return footer
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        return sections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        var numberOfItemsInSection: Int = 0
        
        if section < sectionDatasource.sections.count {
            let key = sectionDatasource.sections.object(at: section)
            let datasource = sectionDatasource.sectionArrayRow.object(forKey: key) as! [tableMetadata]
            numberOfItemsInSection = datasource.count
        }
        
        return numberOfItemsInSection
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        
        NCMainCommon.sharedInstance.collectionViewCellForItemAt(indexPath, collectionView: collectionView, cell: cell, metadata: metadata, metadataFolder: nil, serverUrl: metadata.serverUrl, isEditMode: isEditMode, selectocId: selectocId, autoUploadFileName: autoUploadFileName, autoUploadDirectory: autoUploadDirectory, hideButtonMore: true, downloadThumbnail: false, shares: nil, source: self)
        
        return cell
    }
}

extension NCMedia: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: sectionHeaderHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        if (section == sections - 1) {
            return CGSize(width: collectionView.frame.width, height: footerHeight)
        } else {
            return CGSize(width: collectionView.frame.width, height: 0)
        }
    }
}

// MARK: - NC API & Algorithm

extension NCMedia {

    public func reloadDataSource(loadNetworkDatasource: Bool, completion: @escaping ()->()) {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        DispatchQueue.global().async {
            
            let metadatas = NCManageDatabase.sharedInstance.getMedias(account: self.appDelegate.activeAccount, predicate: NSPredicate(format: "account == %@", self.appDelegate.activeAccount))
            self.sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupByField: "date", filterocId: nil, filterTypeFileImage: self.filterTypeFileImage, filterTypeFileVideo: self.filterTypeFileVideo, sorted: "date", ascending: false, activeAccount: self.appDelegate.activeAccount)
            
            DispatchQueue.main.async {
                
                self.collectionView?.reloadData()
                
                if loadNetworkDatasource {
                    self.loadNetworkDatasource()
                }
                
                self.collectionView?.reloadDataThenPerform {
                    self.downloadThumbnail()
                }
                
                completion()
            }
        }
    }
    
    func deleteItems() {
        
        self.isEditMode = false
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        // copy in arrayDeleteMetadata
        for ocId in selectocId {
            if let metadata = NCManageDatabase.sharedInstance.getMedia(predicate: NSPredicate(format: "ocId == %@", ocId)) {
                appDelegate.arrayDeleteMetadata.add(metadata)
            }
        }
        if let metadata = appDelegate.arrayDeleteMetadata.firstObject {
            appDelegate.arrayDeleteMetadata.removeObject(at: 0)
            NCNetworking.sharedInstance.deleteMetadata(metadata as! tableMetadata, user: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: appDelegate.activeUrl) { (errorCode, errorDescription) in }
        }
    }
    
    func search(lteDate: Date, gteDate: Date, addPast: Bool, insertPrevius: Int,setDistantPast: Bool, debug: String) {
        
        // ----- DEBUG -----
#if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy HH:mm"
        print("[LOG] Search: addPast \(addPast), distantPass: \(setDistantPast), Lte: " + dateFormatter.string(from: lteDate) + " - Gte: " + dateFormatter.string(from: gteDate) + " DEBUG: " + debug)
#endif
        // -----------------
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        if addPast && loadingSearch {
            return
        }
        
        if setDistantPast {
            isDistantPast = true
        }
        
        if addPast {
            //CCGraphics.addImage(toTitle: NSLocalizedString("_media_", comment: ""), colorTitle: NCBrandColor.sharedInstance.brandText, imageTitle: CCGraphics.changeThemingColorImage(UIImage.init(named: "load"), multiplier: 2, color: NCBrandColor.sharedInstance.brandText), imageRight: false, navigationItem: self.navigationItem)
            NCUtility.sharedInstance.startActivityIndicator(view: self.view, bottom: 50)
        }
        loadingSearch = true
        
        let startDirectory = NCManageDatabase.sharedInstance.getAccountStartDirectoryMediaTabView(CCUtility.getHomeServerUrlActiveUrl(appDelegate.activeUrl))
        
        OCNetworking.sharedManager()?.search(withAccount: appDelegate.activeAccount, fileName: "", serverUrl: startDirectory, contentType: ["image/%", "video/%"], lteDateLastModified: lteDate, gteDateLastModified: gteDate, depth: "infinity", completion: { (account, metadatas, message, errorCode) in
            
            self.refreshControl.endRefreshing()
            NCUtility.sharedInstance.stopActivityIndicator()
            //self.navigationItem.titleView = nil
            //self.navigationItem.title = NSLocalizedString("_media_", comment: "")
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                var isDifferent: Bool = false
                var newInsert: Int = 0
                
                let totalDistance = Calendar.current.dateComponents([Calendar.Component.day], from: gteDate, to: lteDate).value(for: .day) ?? 0
                
                let difference = NCManageDatabase.sharedInstance.createTableMedia(metadatas as! [tableMetadata], lteDate: lteDate, gteDate: gteDate, account: account!)
                isDifferent = difference.isDifferent
                newInsert = difference.newInsert
                
                self.loadingSearch = false
                
                print("[LOG] Search: Totale Distance \(totalDistance) - It's Different \(isDifferent) - New insert \(newInsert)")
                
                if isDifferent {
                    self.reloadDataSource(loadNetworkDatasource: false) { }
                }
                
                if (isDifferent == false || newInsert+insertPrevius < 100) && addPast && setDistantPast == false {
                    
                    switch totalDistance {
                    case 0...89:
                        if var gteDate90 = Calendar.current.date(byAdding: .day, value: -90, to: gteDate) {
                            gteDate90 = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: gteDate90) ?? Date()
                            self.search(lteDate: lteDate, gteDate: gteDate90, addPast: addPast, insertPrevius: newInsert+insertPrevius, setDistantPast: false, debug: "search recursive -90 gg")
                        }
                    case 90...179:
                        if var gteDate180 = Calendar.current.date(byAdding: .day, value: -180, to: gteDate) {
                            gteDate180 = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: gteDate180) ?? Date()
                            self.search(lteDate: lteDate, gteDate: gteDate180, addPast: addPast, insertPrevius: newInsert+insertPrevius, setDistantPast: false, debug: "search recursive -180 gg")
                        }
                    case 180...364:
                        if var gteDate365 = Calendar.current.date(byAdding: .day, value: -365, to: gteDate) {
                            gteDate365 = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: gteDate365) ?? Date()
                            self.search(lteDate: lteDate, gteDate: gteDate365, addPast: addPast, insertPrevius: newInsert+insertPrevius, setDistantPast: false, debug: "search recursive -365 gg")
                        }
                    default:
                        self.search(lteDate: lteDate, gteDate: NSDate.distantPast, addPast: addPast, insertPrevius: newInsert+insertPrevius, setDistantPast: true, debug: "search recursive distant pass")
                    }
                }
                
                self.collectionView?.reloadDataThenPerform {
                    self.downloadThumbnail()
                }
                
            }  else {
                
                self.loadingSearch = false
                
                self.reloadDataSource(loadNetworkDatasource: false) { }
            }
        })
    }
    
    @objc private func loadNetworkDatasource() {
        
        isDistantPast = false
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        if sectionDatasource.allRecordsDataSource.count == 0 {
            
            let gteDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
            search(lteDate: Date(), gteDate: gteDate!, addPast: true, insertPrevius: 0, setDistantPast: false, debug: "search (add past) today, -30 gg")
            
        } else {
            
            let gteDate = NCManageDatabase.sharedInstance.getTableMediaDate(account: self.appDelegate.activeAccount, order: .orderedAscending)
            search(lteDate: Date(), gteDate: gteDate, addPast: false, insertPrevius: 0, setDistantPast: false, debug: "search today, first date record")
        }
        
        collectionView?.reloadDataThenPerform {
            self.downloadThumbnail()
        }
    }
    
    private func selectSearchSections() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        let sections = NSMutableSet()
        let lastDate = NCManageDatabase.sharedInstance.getTableMediaDate(account: self.appDelegate.activeAccount, order: .orderedDescending)
        var gteDate: Date?
        
        for item in collectionView.indexPathsForVisibleItems {
            if let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(item, sectionDataSource: sectionDatasource) {
                if let date = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: metadata.date as Date) {
                    sections.add(date)
                }
            }
        }
        let sortedSections = sections.sorted { (date1, date2) -> Bool in
            (date1 as! Date).compare(date2 as! Date) == .orderedDescending
        }
        
        if sortedSections.count >= 1 {
            let lteDate = Calendar.current.date(byAdding: .day, value: 1, to: sortedSections.first as! Date)!
            if lastDate == sortedSections.last as! Date {
                gteDate = Calendar.current.date(byAdding: .day, value: -30, to: sortedSections.last as! Date)!
                search(lteDate: lteDate, gteDate: gteDate!, addPast: true, insertPrevius: 0, setDistantPast: false, debug: "search (add past) last record, -30 gg")
            } else {
                gteDate = Calendar.current.date(byAdding: .day, value: -1, to: sortedSections.last as! Date)!
                search(lteDate: lteDate, gteDate: gteDate!, addPast: false, insertPrevius: 0, setDistantPast: false, debug: "search [refresh window]")
            }
        }
    }
    
    private func downloadThumbnail() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for item in self.collectionView.indexPathsForVisibleItems {
                if let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(item, sectionDataSource: self.sectionDatasource) {
                    NCNetworkingMain.sharedInstance.downloadThumbnail(with: metadata, view: self.collectionView as Any, indexPath: item)
                }
            }
        }
    }
}

// MARK: - FastScroll - ScrollView

extension NCMedia: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        collectionView.scrollViewDidScroll(scrollView)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        collectionView.scrollViewWillBeginDragging(scrollView)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        collectionView.scrollViewDidEndDecelerating(scrollView)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        collectionView.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        selectSearchSections()
    }
}

extension NCMedia: FastScrollCollectionViewDelegate {
    
    fileprivate func configFastScroll() {
        
        collectionView.fastScrollDelegate = self
        
        //bubble
        collectionView.deactivateBubble = true
        collectionView.bubbleFocus = .dynamic
        collectionView.bubbleTextSize = 14.0
        collectionView.bubbleMarginRight = 50.0
        collectionView.bubbleColor = UIColor(red: 38.0 / 255.0, green: 48.0 / 255.0, blue: 60.0 / 255.0, alpha: 1.0)
        
        //handle
        /*
        collectionView.handleHeight = 40.0
        collectionView.handleWidth = 40.0
        collectionView.handleRadius = 20.0
        */
        collectionView.handleTimeToDisappear = 1
        collectionView.handleMarginRight = 3
        collectionView.handleColor = NCBrandColor.sharedInstance.brand
        collectionView.handle?.backgroundColor = NCBrandColor.sharedInstance.brand
        
        //scrollbar
        collectionView.scrollbarWidth = 0.0
        collectionView.scrollbarMarginTop = 43.0
        collectionView.scrollbarMarginBottom = 5.0
        collectionView.scrollbarMarginRight = 10.0
        
        //callback action to display bubble name
        /*
        collectionView.bubbleNameForIndexPath = { indexPath in
            let visibleSection: Section = self.data[indexPath.section]
            return visibleSection.sectionTitle
        }
        */
    }
    
    func hideHandle() {
        selectSearchSections()
    }
}

extension FastScrollCollectionView
{
    /// Calls reloadsData() on self, and ensures that the given closure is
    /// called after reloadData() has been completed.
    ///
    /// Discussion: reloadData() appears to be asynchronous. i.e. the
    /// reloading actually happens during the next layout pass. So, doing
    /// things like scrolling the collectionView immediately after a
    /// call to reloadData() can cause trouble.
    ///
    /// This method uses CATransaction to schedule the closure.
    
    func reloadDataThenPerform(_ closure: @escaping (() -> Void))
    {
        CATransaction.begin()
        CATransaction.setCompletionBlock(closure)
        self.reloadData()
        CATransaction.commit()
    }
}

