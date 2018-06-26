//
//  FileProviderExtension+Network.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
//  Copyright © 2018 TWS. All rights reserved.
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

import FileProvider

extension FileProviderExtension {

    // --------------------------------------------------------------------------------------------
    //  MARK: - Read folder
    // --------------------------------------------------------------------------------------------
    
    func readFolder(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        var serverUrl: String?
        var counter = 0
        
        if (enumeratedItemIdentifier == .rootContainer) {
            
            serverUrl = providerData.homeServerUrl
            
        } else {
            
            guard let metadata = providerData.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier) else {
                return
            }
            guard let directorySource = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "directoryID == %@", metadata.directoryID)) else {
                return
            }
            
            serverUrl = directorySource.serverUrl + "/" + metadata.fileName
        }
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.readFolder(serverUrl, depth: "1", account: providerData.account, success: { (metadatas, metadataFolder, directoryID) in
            
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "directoryID == %@ AND session == ''", directoryID!), clearDateReadDirectoryID: directoryID!)
            guard let metadatasUpdate = NCManageDatabase.sharedInstance.addMetadatas(metadatas as! [tableMetadata], serverUrl: serverUrl) else {
                return
            }
            
            for metadata in metadatasUpdate {
             
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: enumeratedItemIdentifier, providerData: self.providerData)
             
                self.providerData.queueTradeSafe.sync(flags: .barrier) {
                    self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                }
             
                counter += 1
                if counter >= self.providerData.itemForPage {
                    //self.signalEnumerator(for: [enumeratedItemIdentifier])
                    counter = 0
                }
             }
             
            //self.signalEnumerator(for: [enumeratedItemIdentifier])
            
        }, failure: { (errorMessage, errorCode) in
        })
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - Delete
    // --------------------------------------------------------------------------------------------
    
    func deleteFile(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, parentItemIdentifier: NSFileProviderItemIdentifier, metadata: tableMetadata, serverUrl: String) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.deleteFileOrFolder(metadata.fileName, serverUrl: serverUrl, success: {
            
            self.deleteFileSystem(for: metadata, serverUrl: serverUrl, itemIdentifier: itemIdentifier)
            
        }, failure: { (errorMessage, errorCode) in
            
            // file not found ? delete
            if errorCode == 404 {
                
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: nil)
            
                // remove itemIdentifier on fileProviderSignalDeleteItemIdentifier
                self.providerData.queueTradeSafe.sync(flags: .barrier) {
                    self.providerData.fileProviderSignalDeleteContainerItemIdentifier.removeValue(forKey: itemIdentifier)
                    self.providerData.fileProviderSignalDeleteWorkingSetItemIdentifier.removeValue(forKey: itemIdentifier)
                }
            
                self.providerData.signalEnumerator(for: [parentItemIdentifier, .workingSet])
            }
        })
    }
    
    func deleteFileSystem(for metadata: tableMetadata, serverUrl: String, itemIdentifier: NSFileProviderItemIdentifier) {
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageFileID(itemIdentifier.rawValue)!
        do {
            try self.providerData.fileManager.removeItem(atPath: fileNamePath)
        } catch let error {
            print("error: \(error)")
        }
        
        if metadata.directory {
            let dirForDelete = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)
            NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete!)
        }
        
        NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: nil)
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - Favorite
    // --------------------------------------------------------------------------------------------
    
    func settingFavorite(_ favorite: Bool, withIdentifier itemIdentifier: NSFileProviderItemIdentifier, parentItemIdentifier: NSFileProviderItemIdentifier, metadata: tableMetadata) {

        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: serverUrl, activeUrl: self.providerData.accountUrl)

        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.settingFavorite(fileNamePath, favorite: favorite, success: {
                    
            // Change DB
            metadata.favorite = favorite
            _ = NCManageDatabase.sharedInstance.addMetadata(metadata)                    
            
        }, failure: { (errorMessage, errorCode) in
            
            // Errore, remove from listFavoriteIdentifierRank
            self.providerData.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)

            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: self.providerData)
            
            self.providerData.queueTradeSafe.sync(flags: .barrier) {
                self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            }
            
            self.providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
        })
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - Upload
    // --------------------------------------------------------------------------------------------
    
    func uploadStart(_ fileID: String!, account: String!, task: URLSessionUploadTask!, serverUrl: String!) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }

        guard let metadataUpload = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        
        metadataUpload.status = Int(k_metadataStatusUploading)
        guard let metadata = NCManageDatabase.sharedInstance.addMetadata(metadataUpload) else {
            return
        }
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)

        // Register for bytesSent
        NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(item.itemIdentifier.rawValue)) { (error) in }
        
        providerData.queueTradeSafe.sync(flags: .barrier) {
            self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        
        self.providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
    }
    
    func uploadFileSuccessFailure(_ fileName: String!, fileID: String!, assetLocalIdentifier: String!, serverUrl: String!, selector: String!, selectorPost: String!, errorMessage: String!, errorCode: Int) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            return
        }
        
        // OK
        if errorCode == 0 {
            
            // importDocument
            if (selectorPost == providerData.selectorPostImportDocument) {
                providerData.queueTradeSafe.sync(flags: .barrier) {
                    let itemIdentifier = NSFileProviderItemIdentifier(assetLocalIdentifier)
                    self.providerData.fileProviderSignalDeleteContainerItemIdentifier[itemIdentifier] = itemIdentifier
                    self.providerData.fileProviderSignalDeleteWorkingSetItemIdentifier[itemIdentifier] = itemIdentifier
                }
            }
            
            // itemChanged
            if (selectorPost == providerData.selectorPostItemChanged) {
                // Recreate ico
                CCGraphics.createNewImage(from: fileName, fileID: fileID, extension: NSString(string: fileName).pathExtension, size: "m", imageForUpload: false, typeFile: metadata.typeFile, writeImage: true, optimizedFileName: false)
            }
                        
            // remove session data
            metadata.assetLocalIdentifier = ""
            metadata.session = ""
            metadata.sessionSelector = ""
            metadata.sessionSelectorPost = ""
            let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata)
            
            let item = FileProviderItem(metadata: metadata!, parentItemIdentifier: parentItemIdentifier, providerData: providerData)

            providerData.queueTradeSafe.sync(flags: .barrier) {
                self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            }
            
            uploadFileImportDocument()
            
        } else {
        
            // Error
            
            metadata.status = Int(k_metadataStatusUploadError)
            let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata)
            
            let item = FileProviderItem(metadata: metadata!, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
            
            providerData.queueTradeSafe.sync(flags: .barrier) {
                providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            }
        }
        
        self.providerData.signalEnumerator(for: [parentItemIdentifier, .workingSet])
    }
    
    func uploadFileImportDocument() {
        
        let tableMetadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND (status == %d OR status == %d)", providerData.account, k_upload_session_extension, k_metadataStatusInUpload, k_metadataStatusUploading), sorted: "fileName", ascending: true)
        
        if (tableMetadatas == nil || (tableMetadatas!.count < Int(k_maxConcurrentOperationUpload))) {
            
            guard let metadataForUpload = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND session == %@ AND status == %d", providerData.account, k_upload_session_extension, k_metadataStatusWaitUpload)) else {
                return
            }
            
            CCNetworking.shared().uploadFile(metadataForUpload, taskStatus: Int(k_taskStatusResume), delegate: self)
        }
    }
    
    func uploadFileItemChanged(for itemIdentifier: NSFileProviderItemIdentifier, url: URL) {
        
        guard let metadata = providerData.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return
        }
        
        metadata.assetLocalIdentifier = ""
        metadata.session = k_upload_session_extension
        metadata.sessionSelector = selectorUploadFile
        metadata.sessionSelectorPost = providerData.selectorPostItemChanged
        metadata.status = Int(k_metadataStatusWaitUpload)

        guard let metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
            return
        }
        
        CCNetworking.shared().uploadFile(metadataForUpload, taskStatus: Int(k_taskStatusResume), delegate: self)
    }
    
    func reUpload(_ metadata: tableMetadata) {
        
        metadata.status = Int(k_metadataStatusWaitUpload)
        let metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(metadata)
        
        CCNetworking.shared().uploadFile(metadataForUpload, taskStatus: Int(k_taskStatusResume), delegate: self)
    }
}
