//
//  NCCollectionCommon+CellDelegate.swift
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

extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate {
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {
        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: image, sender: sender)
    }

    func tapShareListItem(with objectId: String, sender: Any) {
        if isEditMode { return }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }
        NCFunctionCenter.shared.openShare(viewController: self, metadata: metadata, indexPage: .sharing)
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        if isEditMode { return }

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        if namedButtonMore == NCGlobal.shared.buttonMoreMore {
            toggleMenu(metadata: metadata, imageIcon: image)
        } else if namedButtonMore == NCGlobal.shared.buttonMoreStop {
            NCNetworking.shared.cancelTransferMetadata(metadata) { }
        }
    }
}

extension NCCollectionViewCommon: UIContextMenuInteractionDelegate {
    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: { return nil }, actionProvider: { _ in return nil })
    }
}
