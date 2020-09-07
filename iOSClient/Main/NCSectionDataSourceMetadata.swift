//
//  NCSectionDataSourceMetadata.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/09/2020.
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

class NCSectionDataSourceMetadata: NSObject {
    
    override init() {
        super.init()
    }
    
    @objc func creataDataSourseSectionMetadata(metadatasSource: [tableMetadata], sort: String, ascending: Bool, groupBy: String? = nil, directoryOnTop: Bool, filterLivePhoto: Bool) -> [tableMetadata] {
        
        var metadatas: [tableMetadata] = []
        var metadatasFavorite: [tableMetadata] = []
        var numDirectory: Int = 0
        var numDirectoryFavorite:Int = 0
        

        /*
        Metadata order
        */
        
        let metadatasSourceSorted = metadatasSource.sorted { (obj1:tableMetadata, obj2:tableMetadata) -> Bool in
            if sort == "date" {
                if ascending {
                    return obj1.date.compare(obj2.date as Date) == ComparisonResult.orderedAscending
                } else {
                    return obj1.date.compare(obj2.date as Date) == ComparisonResult.orderedDescending
                }
            } else if sort == "sessionTaskIdentifier" {
                if ascending {
                    return obj1.sessionTaskIdentifier < obj2.sessionTaskIdentifier
                } else {
                    return obj1.sessionTaskIdentifier > obj2.sessionTaskIdentifier
                }
            } else if sort == "size" {
                if ascending {
                    return obj1.size < obj2.size
                } else {
                    return obj1.size > obj2.size
                }
            } else {
                let range = Range(NSMakeRange(0, obj1.fileNameView.count), in: obj1.fileNameView)
                if ascending {
                    return obj1.fileNameView.compare(obj1.fileNameView, options: .caseInsensitive, range: range, locale: .current) == ComparisonResult.orderedAscending
                } else {
                    return obj1.fileNameView.compare(obj1.fileNameView, options: .caseInsensitive, range: range, locale: .current) == ComparisonResult.orderedDescending
                }
            }
        }
        
        /*
        Initialize datasource
        */
        
        for metadata in metadatasSourceSorted {
            
            // skipped livePhoto
            if metadata.ext == "mov" && metadata.livePhoto {
                continue
            }
            
            if metadata.directory && directoryOnTop {
                if metadata.favorite {
                    numDirectoryFavorite += 1
                    numDirectory += 1
                    metadatas.insert(metadata, at: numDirectoryFavorite)
                } else {
                    numDirectory += 1
                    metadatas.insert(metadata, at: numDirectory)
                }
            } else {
                if metadata.favorite && directoryOnTop {
                    metadatasFavorite.append(metadata)
                } else {
                    metadatas.append(metadata)
                }
            }
        }
        if directoryOnTop && metadatasFavorite.count > 0 {
            metadatas.insert(contentsOf: metadatasFavorite, at: numDirectory)
        }
                
        /*
        if (directoryOnTop && metadataFilesFavorite.count > 0) {
            [sectionDataSource.metadatas insertObjects:metadataFilesFavorite atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(numDirectoryFavorite, metadataFilesFavorite.count)]]; // Add Favorite files at end of favorite folders
        }
        */
        
        return metadatas
    }
}
