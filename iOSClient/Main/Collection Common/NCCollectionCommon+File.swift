//
//  NCCollectionCommon+File.swift
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

extension NCCollectionViewCommon {
    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let fileNameView = userInfo["fileNameView"] as? String,
              let onlyLocalCache = userInfo["onlyLocalCache"] as? Bool
        else { return }

        if onlyLocalCache {
            reloadDataSource()
        } else if fileNameView.lowercased() == NCGlobal.shared.fileNameRichWorkspace.lowercased() {
            reloadDataSourceNetwork(forced: true)
        } else {
            if let row = dataSource.deleteMetadata(ocId: ocId) {
                let indexPath = IndexPath(row: row, section: 0)
                collectionView?.performBatchUpdates({
                    collectionView?.deleteItems(at: [indexPath])
                }, completion: { _ in
                    self.collectionView?.reloadData()
                })
            }
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrlFrom = userInfo["serverUrlFrom"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }
        // DEL
        if serverUrlFrom == serverUrl && metadata.account == appDelegate?.account {
            if let row = dataSource.deleteMetadata(ocId: ocId) {
                let indexPath = IndexPath(row: row, section: 0)
                collectionView?.performBatchUpdates({
                    collectionView?.deleteItems(at: [indexPath])
                }, completion: { _ in
                    self.collectionView?.reloadData()
                })
            }
            // ADD
        } else if metadata.serverUrl == serverUrl && metadata.account == appDelegate?.account {
            if let row = dataSource.addMetadata(metadata) {
                let indexPath = IndexPath(row: row, section: 0)
                collectionView?.performBatchUpdates({
                    collectionView?.insertItems(at: [indexPath])
                }, completion: { _ in
                    self.collectionView?.reloadData()
                })
            }
        }
    }

    @objc func copyFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrlTo = userInfo["serverUrlTo"] as? String,
              serverUrlTo == self.serverUrl
        else { return }
        reloadDataSource()
    }

    @objc func renameFile(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func createFolder(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            if metadata.serverUrl == serverUrl && metadata.account == appDelegate?.account {
                pushMetadata(metadata)
            }
        } else {
            reloadDataSourceNetwork()
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              dataSource.getIndexMetadata(ocId: metadata.ocId) != nil else { return }
        reloadDataSource()
    }

    @objc func downloadStartFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              let row = dataSource.reloadMetadata(ocId: metadata.ocId),
              collectionView.numberOfSections > 0,
              collectionView.numberOfItems(inSection: 0) > row
        else { return }
        collectionView?.reloadItems(at: [IndexPath(row: row, section: 0)])
    }

    @objc func downloadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              userInfo["errorCode"] is Int,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              let row = dataSource.reloadMetadata(ocId: metadata.ocId),
              collectionView.numberOfSections > 0,
              collectionView.numberOfItems(inSection: 0) > row
        else { return }
        collectionView?.reloadItems(at: [IndexPath(row: row, section: 0)])
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              let row = dataSource.reloadMetadata(ocId: metadata.ocId),
              collectionView.numberOfSections > 0,
              collectionView.numberOfItems(inSection: 0) > row
        else { return }
        collectionView?.reloadItems(at: [IndexPath(row: row, section: 0)])
    }

    @objc func uploadStartFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              metadata.serverUrl == serverUrl,
              metadata.account == appDelegate?.account
        else { return }
        dataSource.addMetadata(metadata)
        self.collectionView?.reloadData()
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let ocIdTemp = userInfo["ocIdTemp"] as? String,
              userInfo["errorCode"] is Int,
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              metadata.serverUrl == serverUrl,
              metadata.account == appDelegate?.account
        else { return }
        dataSource.reloadMetadata(ocId: metadata.ocId, ocIdTemp: ocIdTemp)
        collectionView?.reloadData()
    }

    @objc func uploadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String,
              serverUrl == self.serverUrl,
              account == appDelegate?.account
        else { return }

        if let row = dataSource.deleteMetadata(ocId: ocId) {
            let indexPath = IndexPath(row: row, section: 0)
            collectionView?.performBatchUpdates({
                if indexPath.section < (collectionView?.numberOfSections ?? 0) && indexPath.row < (collectionView?.numberOfItems(inSection: indexPath.section) ?? 0) {
                    collectionView?.deleteItems(at: [indexPath])
                }
            }, completion: { _ in
                self.collectionView?.reloadData()
            })
        } else {
            self.reloadDataSource()
        }
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber,
              let totalBytes = userInfo["totalBytes"] as? Int64,
              let totalBytesExpected = userInfo["totalBytesExpected"] as? Int64,
              let ocId = userInfo["ocId"] as? String,
              let index = dataSource.getIndexMetadata(ocId: ocId),
              let cell = collectionView?.cellForItem(at: IndexPath(row: index, section: 0))
        else { return }

        let status = userInfo["status"] as? Int ?? NCGlobal.shared.metadataStatusNormal

        if let cell = cell as? NCListCell {
            if progressNumber.floatValue == 1 {
                cell.progressView?.isHidden = true
                cell.progressView?.progress = .zero
                cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                    cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
                } else {
                    cell.labelInfo.text = ""
                }
            } else if progressNumber.floatValue > 0 {
                cell.progressView?.isHidden = false
                cell.progressView?.progress = progressNumber.floatValue
                cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
                if status == NCGlobal.shared.metadataStatusInDownload {
                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↓ " + CCUtility.transformedSize(totalBytes)
                } else if status == NCGlobal.shared.metadataStatusInUpload {
                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↑ " + CCUtility.transformedSize(totalBytes)
                }
            }
        } else if let cell = cell as? NCTransferCell {
            if progressNumber.floatValue == 1 {
                cell.progressView?.isHidden = true
                cell.progressView?.progress = .zero
                cell.buttonMore.isHidden = true
                cell.labelInfo.text = ""
            } else if progressNumber.floatValue > 0 {
                cell.progressView?.isHidden = false
                cell.progressView?.progress = progressNumber.floatValue
                cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
                if status == NCGlobal.shared.metadataStatusInDownload {
                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↓ " + CCUtility.transformedSize(totalBytes)
                } else if status == NCGlobal.shared.metadataStatusInUpload {
                    cell.labelInfo.text = CCUtility.transformedSize(totalBytesExpected) + " - ↑ " + CCUtility.transformedSize(totalBytes)
                }
            }
        } else if let cell = cell as? NCGridCell {
            if progressNumber.floatValue == 1 {
                cell.progressView.isHidden = true
                cell.progressView.progress = .zero
                cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
            } else if progressNumber.floatValue > 0 {
                cell.progressView.isHidden = false
                cell.progressView.progress = progressNumber.floatValue
                cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
            }
        }
    }
}
