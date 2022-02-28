//
//  NCCollectionCommon+CollectionView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 23.12.21.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import UIKit
import NCCommunication

// MARK: - Data Source

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as? NCSectionHeaderMenu else { return UICollectionReusableView() }
            self.header = header

            if collectionView.collectionViewLayout == gridLayout {
                header.buttonSwitch.setImage(UIImage(named: "switchList")!.image(color: NCBrandColor.shared.gray, size: 50), for: .normal)
            } else {
                header.buttonSwitch.setImage(UIImage(named: "switchGrid")!.image(color: NCBrandColor.shared.gray, size: 50), for: .normal)
            }

            header.delegate = self
            header.setStatusButton(count: dataSource.metadatas.count)
            header.setTitleSorted(datasourceTitleButton: layoutForView?.titleButtonHeader ?? "")
            header.viewRichWorkspaceHeightConstraint.constant = headerRichWorkspaceHeight
            header.setRichWorkspaceText(richWorkspaceText: richWorkspaceText)

            return header

        } else {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return UICollectionReusableView() }
            let info = dataSource.getFilesInformation()
            footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size )

            return footer
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), let cell = cell as? NCCellProtocol else { return }

        // Thumbnail
        if !metadata.directory {
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                cell.filePreviewImageView?.image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else {
                NCOperationQueue.shared.downloadThumbnail(metadata: metadata, placeholder: true, cell: cell, view: collectionView)
            }
        }

        // Avatar
        if !metadata.ownerId.isEmpty,
           metadata.ownerId != appDelegate?.userId,
           appDelegate?.account == metadata.account {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            NCOperationQueue.shared.downloadAvatar(user: metadata.ownerId, dispalyName: metadata.ownerDisplayName, fileName: fileName, cell: cell, view: collectionView)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberItems = dataSource.numberOfItems()
        emptyDataSet?.numberOfItemsInSection(numberItems, section: section)
        return numberItems
    }

    //
    // LAYOUT LIST
    //
    func makeListCell(for indexPath: IndexPath, metadata: tableMetadata, tableShare: tableShare?) -> UICollectionViewCell {
        guard let appDelegate = appDelegate, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell
        else { return UICollectionViewCell() }
        let (isShare, _) = NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder)

        cell.delegate = self

        setupCellUI(cell, for: metadata, tableShare: tableShare)

        if isSearching {
            cell.labelTitle.text = NCUtilityFileSystem.shared.getPath(metadata: metadata)
            cell.labelTitle.lineBreakMode = .byTruncatingHead
        } else {
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.lineBreakMode = .byTruncatingMiddle
        }
        cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
        cell.labelInfo.textColor = NCBrandColor.shared.systemGray

        // Progress
        let totalBytes: Int64 = appDelegate.listProgress[metadata.ocId]?.totalBytes ?? 0

        // Share image
        if isShare || appDelegate.account != metadata.account || (tableShare != nil && tableShare?.shareType != 3) {
            cell.imageShared.image = NCBrandColor.cacheImages.shared
        } else if tableShare != nil && tableShare?.shareType == 3 {
            cell.imageShared.image = NCBrandColor.cacheImages.shareByLink
        } else {
            cell.imageShared.image = NCBrandColor.cacheImages.canShare
        }

        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_download_", comment: "")
        case NCGlobal.shared.metadataStatusInDownload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_download_", comment: "")
        case NCGlobal.shared.metadataStatusDownloading:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↓ " + CCUtility.transformedSize(totalBytes)
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_upload_", comment: "")
        case NCGlobal.shared.metadataStatusInUpload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_upload_", comment: "")
        case NCGlobal.shared.metadataStatusUploading:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↑ " + CCUtility.transformedSize(totalBytes)
        case NCGlobal.shared.metadataStatusUploadError:
            if !metadata.sessionError.isEmpty {
                cell.labelInfo.text = NSLocalizedString("_status_wait_upload_", comment: "") + " " + metadata.sessionError
            } else {
                cell.labelInfo.text = NSLocalizedString("_status_wait_upload_", comment: "")
            }
        default: break
        }

        // Disable Share Button
        cell.hideButtonShare(metadata.e2eEncrypted || isEncryptedFolder || appDelegate.disableSharesView)

        // Remove last separator
        cell.separator.isHidden = collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1

        return cell
    }

    //
    // LAYOUT GRID
    //
    func makeGridCell(for indexPath: IndexPath, metadata: tableMetadata, tableShare: tableShare?) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell
        else { return UICollectionViewCell() }
        cell.delegate = self
        setupCellUI(cell, for: metadata, tableShare: tableShare)
        return cell

    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            if layoutForView?.layout == NCGlobal.shared.layoutList, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell {
                return cell
            } else if layoutForView?.layout == NCGlobal.shared.layoutGrid, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell {
                return cell
            } else { return UICollectionViewCell() }
        }

        let tableShare = dataSource.metadataShare[metadata.ocId]

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            return makeListCell(for: indexPath, metadata: metadata, tableShare: tableShare)
        } else if layoutForView?.layout == NCGlobal.shared.layoutGrid {
            return makeGridCell(for: indexPath, metadata: metadata, tableShare: tableShare)
        }

        return UICollectionViewCell()
    }

    func setupCellUI(_ cell: NCMetadataCell, for metadata: tableMetadata, tableShare: tableShare?) {
        guard let appDelegate = appDelegate else { return }
        cell.resetUI(for: metadata)

        // Progress
        let progress = appDelegate.listProgress[metadata.ocId]?.progress ?? 0
        let isInProgress = metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading
        cell.progressView.isHidden = !isInProgress
        cell.progressView.progress = isInProgress ? progress : 0.0

        if metadata.directory {
            let (isShare, isMounted) = NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder)

            if metadata.e2eEncrypted {
                cell.imageItem.image = NCBrandColor.cacheImages.folderEncrypted
            } else if isShare {
                cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if tableShare != nil && tableShare?.shareType != 3 {
                cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if tableShare != nil && tableShare?.shareType == 3 {
                cell.imageItem.image = NCBrandColor.cacheImages.folderPublic
            } else if metadata.mountType == "group" {
                cell.imageItem.image = NCBrandColor.cacheImages.folderGroup
            } else if isMounted {
                cell.imageItem.image = NCBrandColor.cacheImages.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.imageItem.image = NCBrandColor.cacheImages.folderAutomaticUpload
            } else {
                cell.imageItem.image = NCBrandColor.cacheImages.folder
            }

            // Local image: offline
            if let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName),
               let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl)),
               tableDirectory.offline {
                cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
            }

        } else {

            // image Local
            if dataSource.metadataOffLine.contains(metadata.ocId) {
                cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
            } else if CCUtility.fileProviderStorageExists(metadata) {
                cell.imageLocal.image = NCBrandColor.cacheImages.local
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = NCBrandColor.cacheImages.favorite
        }

        if [NCGlobal.shared.metadataStatusInDownload, NCGlobal.shared.metadataStatusDownloading, NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading].contains(metadata.status) {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
        } else {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
        }

        // Live Photo
        if metadata.livePhoto {
            cell.imageStatus.image = NCBrandColor.cacheImages.livePhoto
        }

        // Edit mode
        cell.selectMode(isEditMode)
        cell.selected(isEditMode && selectOcId.contains(metadata.ocId))
    }
}

// MARK: - Delegate

extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        appDelegate?.activeMetadata = metadata

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            self.navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
            return
        }

        if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: appDelegate?.account) {
            NCContentPresenter.shared.messageNotification("_info_", description: "_e2e_goto_settings_for_enable_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorE2EENotEnabled)
            return
        }

        if metadata.directory {
            pushMetadata(metadata)
        } else if !(self is NCFileViewInFolder) {
            let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))

            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                var metadatas: [tableMetadata] = []
                for metadata in dataSource.metadatas {
                    if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                        metadatas.append(metadata)
                    }
                }
                NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: imageIcon)
                return
            }

            if CCUtility.fileProviderStorageExists(metadata) {
                NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
            } else if NCCommunication.shared.isNetworkReachable() {
                NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileView) { _ in }
            } else {
                NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorOffline)
            }
        }
    }

    func pushViewController(viewController: UIViewController, onlyIfLoaded: Bool = false) {
        guard !pushed else { return }
        if onlyIfLoaded, !viewController.isViewLoaded { return }
        pushed = true
        navigationController?.pushViewController(viewController, animated: true)
    }

    func collectionViewSelectAll() {
        selectOcId = dataSource.metadatas.map({ $0.ocId })
        navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
        collectionView.reloadData()
    }

    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        if isEditMode || collectionView.cellForItem(at: indexPath) is NCTransferCell { return nil }
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return nil }
        let identifier = indexPath as NSCopying
        var image: UIImage?
        let cell = collectionView.cellForItem(at: indexPath)
        if let cell = cell as? NCListCell {
            image = cell.imageItem.image
        } else if let cell = cell as? NCGridCell {
            image = cell.imageItem.image
        }

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCFunctionCenter.shared.contextMenuConfiguration(ocId: metadata.ocId, viewController: self, enableDeleteLocal: true, enableViewInFolder: false, image: image)
        })
    }

    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
    }
}

// MARK: - Layout

extension NCCollectionViewCommon: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

        headerRichWorkspaceHeight = 0

        if let richWorkspaceText = richWorkspaceText {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !isSearching {
                headerRichWorkspaceHeight = UIScreen.main.bounds.size.height / 4
            }
        }

        return CGSize(width: collectionView.frame.width, height: headerHeight + headerRichWorkspaceHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: footerHeight)
    }
}

// MARK: - Reload DataSource + NC Endpoint
extension NCCollectionViewCommon {
    @objc func reloadDataSource(_ notification: NSNotification) {

        reloadDataSource()
    }

    @objc func reloadDataSourceNetworkForced(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let serverUrl = userInfo["serverUrl"] as? String {
                if serverUrl == self.serverUrl {
                    reloadDataSourceNetwork(forced: true)
                }
            }
        } else {
            reloadDataSourceNetwork(forced: true)
        }
    }

    @objc func reloadDataSource() {

        guard let appDelegate = appDelegate, !appDelegate.account.isEmpty else { return }

        // Get richWorkspace Text
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace

        // E2EE
        isEncryptedFolder = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: metadataFolder?.e2eEncrypted ?? false, account: appDelegate.account, urlBase: appDelegate.urlBase)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)

        // get layout for view
        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
    }

    @objc func reloadDataSourceNetwork(forced: Bool = false) { }

    @objc func networkReadFolder(
        forced: Bool,
        completion: @escaping(
            _ tableDirectory: tableDirectory?,
            _ metadatas: [tableMetadata]?,
            _ metadatasUpdate: [tableMetadata]?,
            _ metadatasDelete: [tableMetadata]?,
            _ errorCode: Int, _ errorDescription: String) -> Void) {

            var tableDirectory: tableDirectory?

            NCNetworking.shared.readFile(serverUrlFileName: serverUrl) { account, metadataFolder, errorCode, errorDescription in

                guard errorCode == 0 else { return completion(nil, nil, nil, nil, errorCode, errorDescription) }

                if let metadataFolder = metadataFolder {
                    tableDirectory = NCManageDatabase.shared.setDirectory(richWorkspace: metadataFolder.richWorkspace, serverUrl: self.serverUrl, account: account)
                }

                guard let appDelegate = self.appDelegate, (forced || tableDirectory?.etag != metadataFolder?.etag || metadataFolder?.e2eEncrypted ?? false)
                else { return completion(tableDirectory, nil, nil, nil, 0, "") }

                NCNetworking.shared.readFolder(serverUrl: self.serverUrl, account: appDelegate.account) { account, metadataFolder, metadatas, metadatasUpdate, _, metadatasDelete, errorCode, errorDescription in

                    guard errorCode == 0 else { return completion(tableDirectory, nil, nil, nil, errorCode, errorDescription) }
                    self.metadataFolder = metadataFolder

                    // E2EE
                    guard let metadataFolder = metadataFolder, metadataFolder.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account)
                    else { return completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription) }

                    NCCommunication.shared.getE2EEMetadata(fileId: metadataFolder.ocId, e2eToken: nil) { account, e2eMetadata, errorCode, errorDescription in

                        if errorCode == 0 && e2eMetadata != nil {
                            if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: self.serverUrl, account: account, urlBase: appDelegate.urlBase) {

                                NCContentPresenter.shared.messageNotification(
                                    "_error_e2ee_", description: "_e2e_error_decode_metadata_",
                                    delay: NCGlobal.shared.dismissAfterSecond,
                                    type: NCContentPresenter.messageType.error,
                                    errorCode: NCGlobal.shared.errorDecodeMetadata)
                            } else {
                                self.reloadDataSource()
                            }

                        } else if errorCode != NCGlobal.shared.errorResourceNotFound {
                            NCContentPresenter.shared.messageNotification(
                                "_error_e2ee_", description: "_e2e_error_decode_metadata_",
                                delay: NCGlobal.shared.dismissAfterSecond,
                                type: NCContentPresenter.messageType.error,
                                errorCode: NCGlobal.shared.errorDecodeMetadata)
                        }

                        completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription)
                    }
                }
            }
        }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSourceNetwork()
    }
}
