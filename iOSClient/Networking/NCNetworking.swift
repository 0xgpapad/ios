//
//  NCNetworking.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/10/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import OpenSSL
import NCCommunication

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, error: Error?, statusCode: Int)
}

@objc class NCNetworking: NSObject, NCCommunicationCommonDelegate {
    @objc public static let sharedInstance: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()
    
    var account = ""
    
    // Protocol
    var delegate: NCNetworkingDelegate?
    
    //MARK: - Setup
    
    @objc public func setup(account: String, delegate: NCNetworkingDelegate?) {
        self.account = account
        self.delegate = delegate
    }
    
    //MARK: - Communication Delegate
       
    func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if NCNetworking.sharedInstance.checkTrustedChallenge(challenge: challenge, directoryCertificate: CCUtility.getDirectoryCerificates()) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential.init(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
    
    func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.downloadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, error: Error?, statusCode: Int) {
        delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size:size, description: description, error: error, statusCode: statusCode)
    }
    
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, error: error, statusCode: statusCode)
    }
    
    //MARK: - Pinning check
    
    @objc func checkTrustedChallenge(challenge: URLAuthenticationChallenge, directoryCertificate: String) -> Bool {
        
        var trusted = false
        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificateUrl = URL.init(fileURLWithPath: directoryCertificate)
        
        if let trust: SecTrust = protectionSpace.serverTrust {
            saveX509Certificate(trust, certName: "tmp.der", directoryCertificate: directoryCertificate)
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryCertificateUrl, includingPropertiesForKeys: nil)
                let certTmpPath = directoryCertificate+"/"+"tmp.der"
                for file in directoryContents {
                    let certPath = file.path
                    if certPath == certTmpPath { continue }
                    if FileManager.default.contentsEqual(atPath:certTmpPath, andPath: certPath) {
                        trusted = true
                        break
                    }
                }
            } catch { print(error) }
        }
        
        return trusted
    }
    
    @objc func wrtiteCertificate(directoryCertificate: String) {
        
        let certificateAtPath = directoryCertificate + "/tmp.der"
        let certificateToPath = directoryCertificate + "/" + CCUtility.getTimeIntervalSince197() + ".der"
        
        do {
            try FileManager.default.moveItem(atPath: certificateAtPath, toPath: certificateToPath)
        } catch { }
    }
    
    private func saveX509Certificate(_ trust: SecTrust, certName: String, directoryCertificate: String) {
        
        let currentServerCert = secTrustGetLeafCertificate(trust)
        let certNamePath = directoryCertificate + "/" + certName
        let data: CFData = SecCertificateCopyData(currentServerCert!)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        BIO_free(mem)
        if x509cert == nil {
            print("[LOG] OpenSSL couldn't parse X509 Certificate")
        } else {
            if FileManager.default.fileExists(atPath: certNamePath) {
                do {
                    try FileManager.default.removeItem(atPath: certNamePath)
                } catch { }
            }
            let file = fopen(certNamePath, "w")
            if file != nil {
                PEM_write_X509(file, x509cert);
            }
            fclose(file);
            X509_free(x509cert);
        }
    }
    
    private func secTrustGetLeafCertificate(_ trust: SecTrust) -> SecCertificate? {
        
        let result: SecCertificate?
        
        if SecTrustGetCertificateCount(trust) > 0 {
            result = SecTrustGetCertificateAtIndex(trust, 0)!
            assert(result != nil);
        } else {
            result = nil
        }
        
        return result
    }
    
    //MARK: - File <> Metadata
    
    @objc func convertFile(_ file: NCFile, urlString: String, serverUrl : String?, fileName: String, user: String) -> tableMetadata {
        
        let metadata = tableMetadata()
        
        metadata.account = account
        metadata.commentsUnread = file.commentsUnread
        metadata.contentType = file.contentType
        metadata.creationDate = file.creationDate
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.hasPreview = file.hasPreview
        metadata.mountType = file.mountType
        metadata.ocId = file.ocId
        metadata.ownerId = file.ownerId
        metadata.ownerDisplayName = file.ownerDisplayName
        metadata.permissions = file.permissions
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.richWorkspace = file.richWorkspace
        metadata.resourceType = file.resourceType
        if serverUrl == nil {
            metadata.serverUrl = urlString + file.path.replacingOccurrences(of: "dav/files/"+user, with: "webdav").dropLast()
        } else {
            metadata.serverUrl = serverUrl!
        }
        metadata.size = file.size
                   
        CCUtility.insertTypeFileIconName(metadata.fileName, metadata: metadata)
        
        return metadata
    }
    
    @objc func convertFiles(_ files: [NCFile], urlString: String, serverUrl : String?, user: String, metadataFolder: UnsafeMutablePointer<tableMetadata>?) -> [tableMetadata] {
        
        var metadatas = [tableMetadata]()
        
        for file in files {
            
            if !CCUtility.getShowHiddenFiles() && file.fileName.first == "." { continue }
            
            let metadata = tableMetadata()
            
            metadata.account = account
            metadata.commentsUnread = file.commentsUnread
            metadata.contentType = file.contentType
            metadata.creationDate = file.creationDate
            metadata.date = file.date
            metadata.directory = file.directory
            metadata.e2eEncrypted = file.e2eEncrypted
            metadata.etag = file.etag
            metadata.favorite = file.favorite
            metadata.fileId = file.fileId
            metadata.fileName = file.fileName
            metadata.fileNameView = file.fileName
            metadata.hasPreview = file.hasPreview
            metadata.mountType = file.mountType
            metadata.ocId = file.ocId
            metadata.ownerId = file.ownerId
            metadata.ownerDisplayName = file.ownerDisplayName
            metadata.permissions = file.permissions
            metadata.quotaUsedBytes = file.quotaUsedBytes
            metadata.quotaAvailableBytes = file.quotaAvailableBytes
            metadata.richWorkspace = file.richWorkspace
            metadata.resourceType = file.resourceType
            if serverUrl == nil {
                metadata.serverUrl = urlString + file.path.replacingOccurrences(of: "dav/files/"+user, with: "webdav").dropLast()
            } else {
                metadata.serverUrl = serverUrl!
            }
            metadata.size = file.size
                        
            CCUtility.insertTypeFileIconName(metadata.fileName, metadata: metadata)
            
            // Folder
            if file.fileName.count == 0 && metadataFolder != nil {
                metadataFolder!.initialize(to: metadata)
            } else {
                metadatas.append(metadata)
            }
        }
        
        return metadatas
    }
    
    //MARK: - WebDav
    
    @objc func deleteMetadata(_ metadata: tableMetadata, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                
        let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl))
            
        if directory != nil && directory?.e2eEncrypted == true {
            self.deleteMetadataE2EE(metadata, directory: directory!, user: user, userID: userID, password: password, url: url, completion: completion)
        } else {
            // Verify Live Photo
            if let metadataMov = NCUtility.sharedInstance.hasMOV(metadata: metadata) {
                self.deleteMetadataPlain(metadataMov) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        self.deleteMetadataPlain(metadata, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            } else {
                self.deleteMetadataPlain(metadata, completion: completion)
            }
        }
    }
    
    private func deleteMetadataPlain(_ metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        // verify permission
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_delete)
        if metadata.permissions != "" && permission == false {
            
            self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorNotPermission)], errorDescription: "_no_permission_delete_file_", completion: completion)
            return
        }
                
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.sharedInstance.deleteFileOrFolder(serverUrlFileName, account: metadata.account) { (account, errorCode, errorDescription) in
        
            if errorCode == 0 || errorCode == kOCErrorServerPathNotFound {
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                                       
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteMedia(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }
            }
            
            self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    private func deleteMetadataE2EE(_ metadata: tableMetadata, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                        
        DispatchQueue.global().async {
            // LOCK FOLDER
            let error = NCNetworkingEndToEnd.sharedManager().lockFolderEncrypted(onServerUrl: directory.serverUrl, ocId: directory.ocId, user: user, userID: userID, password: password, url: url) as NSError?
            
            DispatchQueue.main.async {
                if error == nil {
                    self.deleteMetadataPlain(metadata) { (errorCode, errorDescription) in
                        
                        if errorCode == 0 {
                            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, directory.serverUrl, metadata.fileName))
                        }
                        
                        DispatchQueue.global().async {
                            NCNetworkingEndToEnd.sharedManager().rebuildAndSendMetadata(onServerUrl: directory.serverUrl, account: self.account, user: user, userID: userID, password: password, url: url)
                        }
                        
                        self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                } else {
                    
                    self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": error!.code], errorDescription: error?.localizedDescription, completion: completion)
                }
            }
        }
    }
    
    @objc func favoriteMetadata(_ metadata: tableMetadata, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: url)!
        let favorite = !metadata.favorite
        
        NCCommunication.sharedInstance.setFavorite(serverUrl: url, fileName: fileName, favorite: favorite, account: metadata.account) { (account, errorCode, errorDescription) in
    
            if errorCode == 0 && metadata.account == account {
                NCManageDatabase.sharedInstance.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
            }
            
            self.NotificationPost(name: k_notificationCenter_favoriteFile, userInfo: ["metadata": metadata, "favorite": favorite, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    @objc func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, user: String, userID: String, password: String, url: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_file_already_exists_", completion: completion)
            return
        }
        
        if directory.e2eEncrypted == true {
            renameMetadataE2EE(metadata, fileNameNew: fileNameNew, directory: directory, user: user, userID: userID, password: password, url: url, completion: completion)
        } else {
            renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
        }
    }
    
    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        
        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
                
        NCCommunication.sharedInstance.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false, account: metadata.account) { (account, errorCode, errorDescription) in
                    
            if errorCode == 0 {
                        
                NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId)
                NCManageDatabase.sharedInstance.renameMedia(fileNameTo: fileNameNew, ocId: metadata.ocId)
                        
                if metadata.directory {
                            
                    let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                    let serverUrlTo = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)!
                    if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                                
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }
                            
                } else {
                            
                    NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: fileNameNew, etag: nil)
                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }
                    let atPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName)!
                    let toPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: fileNameNew)!
                    do {
                        try FileManager.default.moveItem(atPath: atPathIcon, toPath: toPathIcon)
                    } catch { }
                }
            }
                    
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    private func renameMetadataE2EE(_ metadata: tableMetadata, fileNameNew: String, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        // verify if exists the new fileName
        if NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_file_already_exists_", completion: completion)

        } else {
            
            DispatchQueue.global().async {
                
                if let error = NCNetworkingEndToEnd.sharedManager()?.sendMetadata(onServerUrl: metadata.serverUrl, fileNameRename: metadata.fileName, fileNameNewRename: fileNameNew, account: metadata.account, user: user, userID: userID, password: password, url: url) as NSError? {
                    
                    self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    
                } else {
                    NCManageDatabase.sharedInstance.setMetadataFileNameView(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)
                    
                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }
                    let atPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    let toPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: fileNameNew)!
                    do {
                        try FileManager.default.moveItem(atPath: atPathIcon, toPath: toPathIcon)
                    } catch { }
                    
                    self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
                }
                
                // UNLOCK
                if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: metadata.serverUrl) {
                    if let error = NCNetworkingEndToEnd.sharedManager()?.unlockFolderEncrypted(onServerUrl: metadata.serverUrl, ocId: directory.ocId, token: tableLock.token, user: user, userID: userID, password: password, url: url) as NSError? {
                        
                        self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    }
                }
            }
        }
    }
    
    @objc func createFolder(fileName: String, serverUrl: String, account: String, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        fileNameFolder = NCUtility.sharedInstance.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.count == 0 {
            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "Database error", completion: completion)
            return
        }
        
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder
        NCCommunication.sharedInstance.createFolder(fileNameFolderUrl, account: account) { (account, ocId, date, errorCode, errorDescription) in
            if errorCode == 0 {
                if directory.e2eEncrypted {
                    
                    DispatchQueue.global().async {
                        if let error = NCNetworkingEndToEnd.sharedManager()?.markFolderEncrypted(onServerUrl: fileNameFolderUrl, ocId: ocId, user: user, userID: userID, password: password, url: url) as NSError? {
                            
                            DispatchQueue.main.async {
                                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                            }
                        } else {
                            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                        }
                    }
                } else {
                    self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                }
            } else {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
            }
        }
    }
    
    //MARK: - Notification Post
    
    private func NotificationPost(name: String, userInfo: [AnyHashable : Any], errorDescription: Any?, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        var userInfo = userInfo
        DispatchQueue.main.async {
            
            if errorDescription == nil { userInfo["errorDescription"] = "" }
            else { userInfo["errorDescription"] = NSLocalizedString(errorDescription as! String, comment: "") }
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: name), object: nil, userInfo: userInfo)
            
            completion(userInfo["errorCode"] as! Int, userInfo["errorDescription"] as! String)
        }
    }
}
