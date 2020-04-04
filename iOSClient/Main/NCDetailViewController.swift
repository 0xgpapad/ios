//
//  NCDetailViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import WebKit
import NCCommunication

class NCDetailViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIImageView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
   
    @objc var isNavigationBarHidden = false
    @objc var metadata: tableMetadata?
    @objc var selector: String?
    @objc var favoriteFilterImage: Bool = false
    @objc var mediaFilterImage: Bool = false
    @objc var offlineFilterImage: Bool = false
    
    @objc var viewerImageViewController: NCViewerImageViewController?
    @objc var metadatas = [tableMetadata]()
    
    private let progressHeight: CGFloat = 1.5
    private var videoLayer: AVPlayerLayer?
    private var viewerImageViewControllerLongPressInProgress = false
        
    //MARK: -

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        appDelegate.activeDetail = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeDisplayMode), name: NSNotification.Name(rawValue: k_notificationCenter_splitViewChangeDisplayMode), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_progressTask), object:nil)
               
        NotificationCenter.default.addObserver(self, selector: #selector(synchronizationMedia(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_synchronizationMedia), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadImage(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_menuDownloadImage), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveLivePhoto(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_menuSaveLivePhoto), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: k_notificationCenter_menuDetailClose), object: nil)
        
        changeTheming()

        if metadata != nil  {
            viewFile(metadata: metadata!, selector: selector)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setProgressBar()
        navigateControllerBarHidden(isNavigationBarHidden)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if appDelegate.player != nil && appDelegate.player.rate != 0 {
            appDelegate.player.pause()
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerVideo.sharedInstance.removeObserver()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.setProgressBar()
        }
    }
    
    //MARK: - ProgressBar

    @objc func setProgressBar() {
        
        appDelegate.progressViewDetail.removeFromSuperview()

        guard let navigationController = splitViewController?.viewControllers.last as? UINavigationController else { return }
                        
        appDelegate.progressViewDetail.frame = CGRect(x: 0, y: navigationController.navigationBar.frame.height - (progressHeight*2), width: navigationController.navigationBar.frame.width, height: progressHeight)
        appDelegate.progressViewDetail.setProgress(0, animated: false)
        
        if NCBrandColor.sharedInstance.brand.isLight() {
            appDelegate.progressViewDetail.tintColor = NCBrandColor.sharedInstance.brand.darker(by: 10)
        } else {
            appDelegate.progressViewDetail.tintColor = NCBrandColor.sharedInstance.brand.lighter(by: 20)
        }
        
        appDelegate.progressViewDetail.trackTintColor = .clear
        appDelegate.progressViewDetail.transform = CGAffineTransform(scaleX: 1, y: progressHeight)
        
        navigationController.navigationBar.addSubview(appDelegate.progressViewDetail)
    }
    
    @objc func progress(_ progress: Float) {
        DispatchQueue.main.async {
            self.appDelegate.progressViewDetail.progress = progress
        }
    }
    
    //MARK: - Utility

    func subViewActive() -> UIView? {
        return backgroundView.subviews.first
    }
    
    @objc func navigateControllerBarHidden(_ state: Bool) {
        
        if state  {
            view.backgroundColor = .black
        } else {
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
        
        navigationController?.setNavigationBarHidden(state, animated: false)
        isNavigationBarHidden = state
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        
        if backgroundView.image != nil {
            backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brand.withAlphaComponent(0.4))
        }
        
        if navigationController?.isNavigationBarHidden == false {
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
    }
   
    @objc func changeDisplayMode() {
       if self.view?.window == nil { return }
        
        NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.backgroundView.frame.size, metadata: metadata)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.setProgressBar()
        }
    }
    
    @objc func triggerProgressTask(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        guard let metadata = self.metadata else { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let account = userInfo["account"] as? String, let serverUrl = userInfo["serverUrl"] as? String, let progress = userInfo["progress"] as? Float {
                if account == metadata.account && serverUrl == metadata.serverUrl {
                    self.progress(progress)
                }
            }
        }
    }
    
    @objc func synchronizationMedia(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let type = userInfo["type"] as? String {
                
                if (self.metadata?.typeFile == k_metadataTypeFile_image || self.metadata?.typeFile == k_metadataTypeFile_video || self.metadata?.typeFile == k_metadataTypeFile_audio) && self.mediaFilterImage {
                    
                    if let metadatas = appDelegate.activeMedia.sectionDatasource.metadatas as? [tableMetadata] {
                        self.metadatas = metadatas
                    }
                    
                    if type == "delete" {
                        if metadatas.count > 0 {
                            var index = viewerImageViewController!.index - 1
                            if index < 0 { index = 0}
                            self.metadata = metadatas[index]
                            viewImage()
                        } else {
                            viewUnload()
                        }
                    }
                    
                    if type == "rename" || type == "move"   {
                        viewerImageViewController?.reloadContentViews()
                    }
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                if metadata.account != self.metadata?.account { return }
                
                if errorCode == 0 {
                    
                    // IMAGE
                    if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) && !mediaFilterImage {
                        
                        deleteFile(notification)
                    }
                    
                    // OTHER
                    if (metadata.typeFile == k_metadataTypeFile_document || metadata.typeFile == k_metadataTypeFile_unknown) && metadataNew.ocId == self.metadata?.ocId {
                        
                        self.metadata = metadataNew
                    }
                    
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String{
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                if errorCode == 0 {
                    
                    // IMAGE
                    if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) && !mediaFilterImage {
                    
                        if let metadatas = NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, metadatas: self.metadatas, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) {
                            var index = viewerImageViewController!.index - 1
                            if index < 0 { index = 0}
                            self.metadata = metadatas[index]
                            viewImage()
                        } else {
                            viewUnload()
                        }
                    }
                    
                    // OTHER
                    if (metadata.typeFile == k_metadataTypeFile_document || metadata.typeFile == k_metadataTypeFile_unknown) && metadata.ocId == self.metadata?.ocId {
                        viewUnload()
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                if errorCode == 0 {
                    if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                        self.metadata = metadata
                        
                        // IMAGE
                        if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) && !mediaFilterImage {
                            
                            viewImage()
                        }
                        
                        // OTHER
                        if (metadata.typeFile == k_metadataTypeFile_document || metadata.typeFile == k_metadataTypeFile_unknown) && metadata.ocId == self.metadata?.ocId {
                            self.navigationController?.navigationBar.topItem?.title = metadata.fileNameView
                        }
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }
    
    @objc func downloadFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                // IMAGE
                if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio && errorCode != 0  {

                    viewerImageViewController?.reloadContentViews()
                }
                
                progress(0)
            }
        }
    }
    
    @objc func downloadImage(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                metadata.session = k_download_session
                metadata.sessionError = ""
                metadata.sessionSelector = ""
                metadata.status = Int(k_metadataStatusWaitDownload)
                
                self.metadata = NCManageDatabase.sharedInstance.addMetadata(metadata)
                
                if let index = metadatas.firstIndex(where: { $0.ocId == metadata.ocId }) {
                    metadatas[index] = self.metadata!
                }
                
                appDelegate.startLoadAutoDownloadUpload()
            }
        }
    }
    
    @objc func saveLivePhoto(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataMov = userInfo["metadataMov"] as? tableMetadata {
                let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
                let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
                
                NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
                    self.progress(Float(progress))
                }, completion: { livePhoto, resources in
                    self.progress(0)
                    if resources != nil {
                        NCLivePhoto.saveToLibrary(resources!) { (result) in
                            if !result {
                                NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                            }
                        }
                    } else {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                    }
                })
            }
        }
    }
    
    @objc func viewUnload() {
        if self.view?.window == nil { return }

        metadata = nil
        selector = nil
        
        if let splitViewController = self.splitViewController as? NCSplitViewController {
            if splitViewController.isCollapsed {
                if let navigationController = splitViewController.viewControllers.last as? UINavigationController {
                    navigationController.popToRootViewController(animated: true)
                }
            } else {
                if backgroundView != nil {
                    for view in backgroundView.subviews {
                        view.removeFromSuperview()
                    }
                }
                self.navigationController?.navigationBar.topItem?.title = ""
            }
        }
        
        self.splitViewController?.preferredDisplayMode = .allVisible
        self.navigationController?.isNavigationBarHidden = false
        view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brand.withAlphaComponent(0.4))
    }
    
    //MARK: - View File
    
    @objc func viewFile(metadata: tableMetadata, selector: String?) {
                
        self.metadata = metadata
        self.selector = selector
        self.backgroundView.image = nil
        for view in backgroundView.subviews { view.removeFromSuperview() }

        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) == false {
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerVideo.sharedInstance.removeObserver()
        }
        
        // IMAGE VIDEO AUDIO
        if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_audio || metadata.typeFile == k_metadataTypeFile_video {
            
            viewImage()
            return
        }
        
        // DOCUMENT - INTERNAL VIEWER
        if metadata.typeFile == k_metadataTypeFile_document && selector != nil && selector == selectorLoadFileInternalView {
            
            let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
            let viewerDocumentWeb = NCViewerDocumentWeb.init(frame: frame, configuration: WKWebViewConfiguration())
            
            viewerDocumentWeb.viewDocumentWebAt(metadata, view: backgroundView)
            return
        }
        
        // DOCUMENT
        if metadata.typeFile == k_metadataTypeFile_document {
            
            // PDF
            if metadata.contentType == "application/pdf" {
                if #available(iOS 11.0, *) {
                    
                    let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                    let viewerPDF = NCViewerPDF.init(frame: frame)
                    
                    let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) == false {
                        return
                    }
                    
                    viewerPDF.setupPdfView(filePath: URL(fileURLWithPath: filePath), view: backgroundView)
                    
                } else {
                    
                    let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                    let viewerDocumentWeb = NCViewerDocumentWeb.init(frame: frame, configuration: WKWebViewConfiguration())
                    
                    viewerDocumentWeb.viewDocumentWebAt(metadata, view: backgroundView)
                }
                
                return
            }
            
            // DirectEditinf: Nextcloud Text - OnlyOffice
            if NCUtility.sharedInstance.isDirectEditing(metadata) != nil && appDelegate.reachability.isReachable() {
                
                let editor = NCUtility.sharedInstance.isDirectEditing(metadata)!
                if editor == k_editor_text || editor == k_editor_onlyoffice {
                    
                    NCUtility.sharedInstance.startActivityIndicator(view: backgroundView, bottom: 0)

                    if metadata.url == "" {
                        
                        var customUserAgent: String?
                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
                        
                        if editor == k_editor_onlyoffice {
                            customUserAgent = NCUtility.sharedInstance.getCustomUserAgentOnlyOffice()
                            self.navigationController?.navigationBar.topItem?.title = ""
                        }
                        
                        NCCommunication.sharedInstance.NCTextOpenFile(serverUrl: appDelegate.activeUrl, fileNamePath: fileNamePath, editor: editor, customUserAgent: customUserAgent, account: appDelegate.activeAccount) { (account, url, errorCode, errorMessage) in
                            
                            if errorCode == 0 && account == self.appDelegate.activeAccount && url != nil {
                                
                                let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                                let nextcloudText = NCViewerNextcloudText.init(frame: frame, configuration: WKWebViewConfiguration())
                                nextcloudText.viewerAt(url!, metadata: metadata, editor: editor, view: self.backgroundView, viewController: self)
                                
                            } else if errorCode != 0 {
                                
                                NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                self.navigationController?.popViewController(animated: true)
                                
                            } else {
                                
                                self.navigationController?.popViewController(animated: true)
                            }
                        }
                        
                    } else {
                        
                        if editor == k_editor_onlyoffice {
                            self.navigationController?.navigationBar.topItem?.title = ""
                        } 
                            
                        let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                        let nextcloudText = NCViewerNextcloudText.init(frame: frame, configuration: WKWebViewConfiguration())
                        nextcloudText.viewerAt(metadata.url, metadata: metadata, editor: editor, view: backgroundView, viewController: self)
                    }
                }
                
                return
            }
            
            // RichDocument: Collabora
            if NCUtility.sharedInstance.isRichDocument(metadata) && appDelegate.reachability.isReachable() {
                
                NCUtility.sharedInstance.startActivityIndicator(view: backgroundView, bottom: 0)
                
                if metadata.url == "" {
                    
                    OCNetworking.sharedManager()?.createLinkRichdocuments(withAccount: appDelegate.activeAccount, fileId: metadata.fileId, completion: { (account, url, errorMessage, errorCode) in
                        
                        if errorCode == 0 && account == self.appDelegate.activeAccount && url != nil {
                            
                            let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                            let richDocument = NCViewerRichdocument.init(frame: frame, configuration: WKWebViewConfiguration())
                            richDocument.viewRichDocumentAt(url!, metadata: metadata, view: self.backgroundView, viewController: self)
                            
                        } else if errorCode != 0 {
                            
                            NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            self.navigationController?.popViewController(animated: true)
                            
                        } else {
                            
                            self.navigationController?.popViewController(animated: true)
                        }
                    })
                    
                } else {
                    
                    let richDocument = NCViewerRichdocument.init(frame: backgroundView.frame, configuration: WKWebViewConfiguration())
                    richDocument.viewRichDocumentAt(metadata.url, metadata: metadata, view: backgroundView, viewController: self)
                }
            }
        }
        
        // OTHER
        let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
        let viewerDocumentWeb = NCViewerDocumentWeb.init(frame: frame, configuration: WKWebViewConfiguration())
        
        viewerDocumentWeb.viewDocumentWebAt(metadata, view: backgroundView)
    }
}

//MARK: - viewerImageViewController - Delegate/DataSource

extension NCDetailViewController: NCViewerImageViewControllerDelegate, NCViewerImageViewControllerDataSource {
    
    func viewImage() {
        
        for view in backgroundView.subviews { view.removeFromSuperview() }
        
        if let metadatas = NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, metadatas: self.metadatas, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) {
                            
            var index = 0
            if let indexFound = metadatas.firstIndex(where: { $0.ocId == self.metadata?.ocId }) { index = indexFound }
            // Video -> is a Live Photo ?
            if metadata?.typeFile == k_metadataTypeFile_video && metadata != nil {
                let filename = (metadata!.fileNameView as NSString).deletingPathExtension.lowercased()
                if let indexFound = metadatas.firstIndex(where: { (($0.fileNameView as NSString).deletingPathExtension.lowercased() as String) == filename && $0.typeFile == k_metadataTypeFile_image }) { index = indexFound }
            }
            self.metadatas = metadatas
            
            viewerImageViewController = NCViewerImageViewController(index: index, dataSource: self, delegate: self)
            if viewerImageViewController != nil {
                           
                self.backgroundView.image = nil

                viewerImageViewController!.view.isHidden = true
                
                viewerImageViewController!.enableInteractiveDismissal = true
                
                addChild(viewerImageViewController!)
                backgroundView.addSubview(viewerImageViewController!.view)
                
                viewerImageViewController!.view.frame = CGRect(x: 0, y: 0, width: backgroundView.frame.width, height: backgroundView.frame.height)
                viewerImageViewController!.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                viewerImageViewController!.didMove(toParent: self)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.viewerImageViewController!.changeInViewSize(to: self.backgroundView.frame.size)
                    self.viewerImageViewController!.view.isHidden = false
                }
            }
        }
    }
    
    func numberOfItems(in viewerImageViewController: NCViewerImageViewController) -> Int {
        return metadatas.count
    }

    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, imageAt index: Int, completion: @escaping (_ index: Int, _ image: UIImage?, _ metadata: tableMetadata, _ zoomScale: ZoomScale?, _ error: Error?) -> Void) {
        
        if index >= metadatas.count { return }
        let metadata = metadatas[index]
        let isPreview = CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileNameView)
        let isImage = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0
        
        // Refresh self metadata && title
        if viewerImageViewController.index < metadatas.count {
            self.metadata = metadatas[viewerImageViewController.index]
            self.navigationController?.navigationBar.topItem?.title = self.metadata!.fileNameView
            
        }
        
        // Status Current
        if index == viewerImageViewController.currentItemIndex {
            statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
        }
        
        // Preview for Video
        if metadata.typeFile == k_metadataTypeFile_video && !isPreview && isImage {
            
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
        }
        
        // Original only for actual
        if metadata.typeFile == k_metadataTypeFile_image && isImage && index == viewerImageViewController.index {
                
            if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
                
        // HEIC
        } else if metadata.contentType == "image/heic" && CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 && metadata.hasPreview == false {
            
            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
            
            _ = NCCommunication.sharedInstance.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, progressHandler: { (progress) in
                                
                self.progress(Float(progress.fractionCompleted))
                
            }) { (account, etag, date, length, errorCode, errorDescription) in
                
                self.progress(0)
                
                if errorCode == 0 && account == metadata.account {
                    
                    _ = NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    
                    if let image = UIImage.init(contentsOfFile: fileNameLocalPath) {
                        
                        CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
                        
                        completion(index, image, metadata, ZoomScale.default, nil)
                    } else {
                        completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                    }
                } else if errorCode != 0 {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
            }
        
        // Preview
        } else if isPreview {
                
            if let image = NCViewerImageCommon.shared.getThumbnailImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
    
        } else if metadata.hasPreview {
                
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    
            NCCommunication.sharedInstance.downloadPreview(serverUrl: appDelegate.activeUrl, fileNamePath: fileNamePath, fileNameLocalPath: fileNameLocalPath, width: Int(k_sizePreview), height: Int(k_sizePreview), account: metadata.account) { (account, data, errorCode, errorMessage) in
                if errorCode == 0 && data != nil {
                    completion(index, UIImage.init(data: data!), metadata, ZoomScale.default, nil)
                } else {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
            }
        } else {
            completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
        }
    }
    
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, didChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata) {
                
        if metadata.typeFile == k_metadataTypeFile_image {
            DispatchQueue.global().async {
                if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
                        view.image = image
                    }
                }
            }
        }
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
    }
    
    func viewerImageViewControllerTap(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        guard let navigationController = self.navigationController else { return }
        
        if metadata.typeFile == k_metadataTypeFile_image {
        
            if navigationController.isNavigationBarHidden {
                navigateControllerBarHidden(false)
                viewerImageViewController.statusView.isHidden = false
            } else {
                navigateControllerBarHidden(true)
                viewerImageViewController.statusView.isHidden = true
            }
            
            NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.backgroundView.frame.size, metadata: metadata)
            
        } else {
            
            if let viewerImageVideo = UIStoryboard(name: "NCViewerImageVideo", bundle: nil).instantiateInitialViewController() as? NCViewerImageVideo {
                viewerImageVideo.metadata = metadata
                present(viewerImageVideo, animated: false) { }
            }
        }
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
    }
    
    func viewerImageViewControllerLongPressBegan(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        viewerImageViewControllerLongPressInProgress = true
        
        let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
        if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", metadata.account, metadata.serverUrl, fileName)) {
            
            if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 {
                
                viewMOV(viewerImageViewController: viewerImageViewController, metadata: metadata)
                
            } else {
                
                let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
                                
                _ = NCCommunication.sharedInstance.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, progressHandler: { (progress) in
                                    
                    self.progress(Float(progress.fractionCompleted))
                    
                }) { (account, etag, date, length, errorCode, errorDescription) in
                    
                    self.progress(0)
                    
                    if errorCode == 0 && account == metadata.account {
                        
                        _ = NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                        self.viewMOV(viewerImageViewController: viewerImageViewController, metadata: metadata)
                    }
                }
            }
        }
    }
    
    func viewerImageViewControllerLongPressEnded(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        viewerImageViewControllerLongPressInProgress = false
        
        appDelegate.player?.pause()
        videoLayer?.removeFromSuperlayer()
    }
    
    func viewerImageViewControllerDismiss() {
        viewUnload()
    }
    
    func statusViewImage(metadata: tableMetadata, viewerImageViewController: NCViewerImageViewController) {
        
        var colorStatus: UIColor = UIColor.white.withAlphaComponent(0.8)
        if view.backgroundColor?.isLight() ?? true { colorStatus = UIColor.black.withAlphaComponent(0.8) }
                
        if NCUtility.sharedInstance.hasMOV(metadata: metadata) != nil {
            viewerImageViewController.statusView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: colorStatus)
        } else if metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            viewerImageViewController.statusView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: colorStatus)
        } else {
            viewerImageViewController.statusView.image = nil
        }
    }
    
    func viewMOV(viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        if !viewerImageViewControllerLongPressInProgress { return }
        
        appDelegate.player = AVPlayer(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!))
        videoLayer = AVPlayerLayer(player: appDelegate.player)
        if  videoLayer != nil {
            videoLayer!.frame = viewerImageViewController.view.frame
            videoLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
            viewerImageViewController.view.layer.addSublayer(videoLayer!)
            appDelegate.player?.play()
        }
    }
}

//MARK: -

extension NCDetailViewController: NCSelectDelegate {
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, buttonType: String, overwrite: Bool) {
        
        if let metadata = self.metadata, let serverUrl = serverUrl {
            NCNetworking.sharedInstance.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { (errorCode, errorDescription) in }
        }
    }
}

