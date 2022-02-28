//
//  NCCollectionCommon+NCDelegate.swift
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

extension NCCollectionViewCommon: NCAccountRequestDelegate, NCBackgroundImageColorDelegate, NCEmptyDataSetDelegate, NCSectionHeaderMenuDelegate {
    func accountRequestAddAccount() {
        appDelegate?.openLogin(viewController: self, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
    }

    func accountRequestChangeAccount(account: String) {
        NCManageDatabase.shared.setAccountActive(account)
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {

            NCOperationQueue.shared.cancelAllQueue()
            NCNetworking.shared.cancelAllTask()

            appDelegate?.settingAccount(
                activeAccount.account,
                urlBase: activeAccount.urlBase,
                user: activeAccount.user,
                userId: activeAccount.userId,
                password: CCUtility.getPassword(activeAccount.account))

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize)
        }
    }

    // MARK: - BackgroundImageColor Delegate

    func colorPickerCancel() {
        changeTheming()
    }

    func colorPickerWillChange(color: UIColor) {
        collectionView.backgroundColor = color
    }

    func colorPickerDidChange(lightColor: String, darkColor: String) {

        NCManageDatabase.shared.setAccountColorFiles(lightColorBackground: lightColor, darkColorBackground: darkColor)

        changeTheming()
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {

        if isSearching {
            view.emptyImage.image = UIImage(named: "search")?.image(color: .gray, size: UIScreen.main.bounds.width)
            if isReloadDataSourceNetworkInProgress {
                view.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                view.emptyTitle.text = NSLocalizedString("_search_no_record_found_", comment: "")
            }
            view.emptyDescription.text = NSLocalizedString("_search_instruction_", comment: "")
        } else if isReloadDataSourceNetworkInProgress {
            view.emptyImage.image = UIImage(named: "networkInProgress")?.image(color: .gray, size: UIScreen.main.bounds.width)
            view.emptyTitle.text = NSLocalizedString("_request_in_progress_", comment: "")
            view.emptyDescription.text = ""
        } else {
            if serverUrl.isEmpty {
                view.emptyImage.image = emptyImage
                view.emptyTitle.text = NSLocalizedString(emptyTitle, comment: "")
                view.emptyDescription.text = NSLocalizedString(emptyDescription, comment: "")
            } else {
                view.emptyImage.image = UIImage(named: "folder")?.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width)
                view.emptyTitle.text = NSLocalizedString("_files_no_files_", comment: "")
                view.emptyDescription.text = NSLocalizedString("_no_file_pull_down_", comment: "")
            }
        }
    }

    func tapSwitchHeader(sender: Any) {

        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCUtility.shared.setLayoutForView(key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { _ in
                    self.collectionView.reloadData()
                })
            })
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCUtility.shared.setLayoutForView(key: layoutKey, serverUrl: serverUrl, layout: layoutForView?.layout)
        }
    }

    func tapOrderHeader(sender: Any) {
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: layoutKey, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }

    func tapMoreHeader(sender: Any) { }

    func tapRichWorkspace(sender: Any) {
        guard let navigationController = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let viewerRichWorkspace = navigationController.topViewController as? NCViewerRichWorkspace
        else { return }
        viewerRichWorkspace.richWorkspaceText = richWorkspaceText ?? ""
        viewerRichWorkspace.serverUrl = serverUrl
        navigationController.modalPresentationStyle = .fullScreen
        self.present(navigationController, animated: true, completion: nil)
    }
}
