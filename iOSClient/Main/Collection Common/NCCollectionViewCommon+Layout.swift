//
//  NCCollectionCommon+CollectionView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 28.02.22.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
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

// MARK: - Layout
extension NCCollectionViewCommon {
    @objc func changeTheming() {

        view.backgroundColor = NCBrandColor.shared.systemBackground
        collectionView.backgroundColor = NCBrandColor.shared.systemBackground
        refreshControl.tintColor = .gray

        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        // IMAGE BACKGROUND
        if let imageBackgroud = layoutForView?.imageBackgroud, !imageBackgroud.isEmpty {
            let imagePath = CCUtility.getDirectoryGroup().appendingPathComponent(NCGlobal.shared.appBackground).path + "/" + imageBackgroud
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: imagePath))
                if let image = UIImage(data: data) {
                    backgroundImageView.image = image
                    backgroundImageView.contentMode = .scaleToFill
                    collectionView.backgroundView = backgroundImageView
                }
            } catch { }
        } else {
            backgroundImageView.image = nil
            collectionView.backgroundView = nil
        }

        // COLOR BACKGROUND
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        if traitCollection.userInterfaceStyle == .dark {
            if activeAccount?.darkColorBackground.isEmpty == true {
                collectionView.backgroundColor = NCBrandColor.shared.systemBackground
            } else {
                collectionView.backgroundColor = UIColor(hex: activeAccount?.darkColorBackground ?? "")
            }
        } else {
            if activeAccount?.lightColorBackground.isEmpty == true {
                collectionView.backgroundColor = NCBrandColor.shared.systemBackground
            } else {
                collectionView.backgroundColor = UIColor(hex: activeAccount?.lightColorBackground ?? "")
            }
        }

        collectionView.reloadData()
    }

    @objc func setNavigationItem() {
        self.setNavigationHeader()
        guard !isEditMode, layoutKey == NCGlobal.shared.layoutViewFiles else { return }

        // PROFILE BUTTON

        let activeAccount = NCManageDatabase.shared.getActiveAccount()

        let image = NCUtility.shared.loadUserImage(
            for: appDelegate.user,
               displayName: activeAccount?.displayName,
               userBaseUrl: appDelegate)

        let button = UIButton(type: .custom)
        button.setImage(image, for: .normal)

        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account) {
            var titleButton = "  "

            if getNavigationTitle() == activeAccount?.alias {
                titleButton = ""
            } else {
                titleButton += activeAccount?.displayName ?? ""
            }

            button.setTitle(titleButton, for: .normal)
            button.setTitleColor(.systemBlue, for: .normal)
        }

        button.semanticContentAttribute = .forceLeftToRight
        button.sizeToFit()
        button.action(for: .touchUpInside) { _ in

            let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
            if !accounts.isEmpty {
                if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

                    vcAccountRequest.activeAccount = NCManageDatabase.shared.getActiveAccount()
                    vcAccountRequest.accounts = accounts
                    vcAccountRequest.enableTimerProgress = false
                    vcAccountRequest.enableAddAccount = true
                    vcAccountRequest.delegate = self
                    vcAccountRequest.dismissDidEnterBackground = true

                    let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
                    let numberCell = accounts.count + 1
                    let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)
                    let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height)

                    UIApplication.shared.keyWindow?.rootViewController?.present(popup, animated: true)
                }
            }
        }
        navigationItem.setLeftBarButton(UIBarButtonItem(customView: button), animated: true)
        navigationItem.leftItemsSupplementBackButton = true
    }

    func getNavigationTitle() -> String {
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        guard let userAlias = activeAccount?.alias, !userAlias.isEmpty else {
            return NCBrandOptions.shared.brand
        }
        return userAlias
    }
}
