//
//  BaseGalleryObject.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


enum GalleryObjectSource {
    case library
    case cloud
    case iTunes
    
    init(sourceType: PHAssetSourceType) {
        if sourceType == .typeCloudShared {
            self = .cloud
        } else if sourceType == .typeiTunesSynced {
            self = .iTunes
        } else {
            self = .library
        }
    }
    
    var canDelete: Bool {
        return self != .iTunes
    }
    
    var canEdit: Bool {
        return self == .library
    }
    
}



/// Base class of gallery object.
open class BaseGalleryObject {

    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
    }


    // MARK: Object properties


    /// Source of object
    lazy var source: GalleryObjectSource = {
        return GalleryObjectSource(sourceType: self.asset.sourceType)
    }()
    
    /// Pixel size of object
    lazy var size: CGSize = {
        return CGSize(width: self.asset.pixelWidth, height: self.asset.pixelHeight)
    }()
    
    /// Creation date of object
    lazy var creationDate: Date? = {
        return self.asset.creationDate
    }()
    
    /// Modification date of object
    lazy var modificationDate: Date? = {
        return self.asset.modificationDate
    }()
    
    /// The location saved with the object
    lazy var location: CLLocation? = {
        return self.asset.location
    }()
    
    /// A boolean value that indicates whether the user has hidden the object
    lazy var isHidden: Bool = {
        return self.asset.isHidden
    }()
    
    /// A Boolean value that indicates whether the user has marked the asset as a favorite
    lazy var isFavorite: Bool = {
        return self.asset.isFavorite
    }()

}

// MARK: Object methods

extension BaseGalleryObject {

    open func canPerform(_ editOperation: PHAssetEditOperation) -> Bool {
        return asset.canPerform(editOperation)
    }

}
