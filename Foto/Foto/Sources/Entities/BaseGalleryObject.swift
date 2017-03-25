//
//  BaseGalleryObject.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


/// Base class of gallery object.
class BaseGalleryObject {

    fileprivate let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
    }

}

// MARK: Asset properties

extension BaseGalleryObject {

    /// Pixel size of object
    var size: CGSize {
        return CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
    }
    
    /// Creation date of object
    var creationDate: Date? {
        return asset.creationDate
    }
    
    /// Modification date of object
    var modificationDate: Date? {
        return asset.modificationDate
    }
    
    /// The location saved with the object
    var location: CLLocation? {
        return asset.location
    }
    
    /// A boolean value that indicates whether the user has hidden the object
    var isHidden: Bool {
        return asset.isHidden
    }
    
    /// A Boolean value that indicates whether the user has marked the asset as a favorite
    var isFavorite: Bool {
        return asset.isFavorite
    }

}
