//
//  NCShareQuickStatusMenu.swift
//  Nextcloud
//
//  Created by TSI-mc on 30/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCShareQuickStatusMenu: NSObject {
        
    func toggleMenu(viewController: UIViewController, directory: Bool, tableShare: tableShare) {
        
        print(tableShare.permissions)
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()

//        "_share_read_only_"             = "Read only";
//        "_share_editing_"               = "Editing";
//        "_share_allow_upload_"          = "Allow upload and editing";
//        "_share_file_drop_"             = "File drop (upload only)";
        
//        @objc let permissionReadShare: Int              = 1
//        @objc let permissionUpdateShare: Int            = 2
//        @objc let permissionCreateShare: Int            = 4
//        @objc let permissionDeleteShare: Int            = 8
//        @objc let permissionShareShare: Int             = 16
        
//        @objc let permissionMinFileShare: Int           = 1
//        @objc let permissionMaxFileShare: Int           = 19
//        @objc let permissionMinFolderShare: Int         = 1
//        @objc let permissionMaxFolderShare: Int         = 31
//        @objc let permissionDefaultFileRemoteShareNoSupportShareOption: Int     = 3
//        @objc let permissionDefaultFolderRemoteShareNoSupportShareOption: Int   = 15
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_read_only_", comment: ""),
                icon: UIImage(),
                selected: tableShare.permissions == (NCGlobal.shared.permissionReadShare + NCGlobal.shared.permissionShareShare) || tableShare.permissions == NCGlobal.shared.permissionReadShare,
                on: false,
                action: { menuAction in
                    let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: canShare, andIsFolder: directory)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermissions, userInfo: ["idShare": tableShare.idShare, "permissions": permissions, "hideDownload": tableShare.hideDownload])
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: directory ? NSLocalizedString("_share_allow_upload_", comment: "") : NSLocalizedString("_share_editing_", comment: ""),
                icon: UIImage(),
                selected: tableShare.permissions == NCGlobal.shared.permissionMaxFileShare || tableShare.permissions == NCGlobal.shared.permissionMaxFolderShare ||  tableShare.permissions == NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption,
                on: false,
                action: { menuAction in
                    let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: canShare, andIsFolder: directory)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermissions, userInfo: ["idShare": tableShare.idShare, "permissions": permissions, "hideDownload": tableShare.hideDownload])
                }
            )
        )
        
        /*
        if directory {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_share_file_drop_", comment: ""),
                    icon: UIImage(),
                    selected: tableShare.permissions == NCGlobal.shared.permissionCreateShare,
                    on: false,
                    action: { menuAction in
                        let permissions = NCGlobal.shared.permissionCreateShare
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermissions, userInfo: ["idShare": tableShare.idShare, "permissions": permissions, "hideDownload": tableShare.hideDownload])
                    }
                )
            )
        }
        */
        
        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
}

