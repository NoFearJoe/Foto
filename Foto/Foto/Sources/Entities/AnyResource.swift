//
//  AnyResource.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


enum ResourceSource {
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


public protocol AnyResourceStore {
    func remove(object: AnyResource)
}


/// Base class of gallery object.
open class AnyResource {

    public class var mediaType: PHAssetMediaType { return .unknown }
    
    
    let asset: PHAsset
    
    let store: AnyResourceStore
    
    
    var pendingRequests: [PHImageRequestID] = []
    
    
    init(asset: PHAsset, store: AnyResourceStore) {
        self.asset = asset
        self.store = store
    }


    // MARK: Object properties


    /// Source of object
    lazy var source: ResourceSource = {
        return ResourceSource(sourceType: self.asset.sourceType)
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

extension AnyResource {

    open func canPerform(_ editOperation: PHAssetEditOperation) -> Bool {
        return asset.canPerform(editOperation)
    }
    
    open func remove() {
        store.remove(object: self)
    }

}


// MARK: Pending requests managing

extension AnyResource {

    func performPendignRequestsChange(_ change: () -> Void) {
        objc_sync_enter(self)
        
        change()
        
        objc_sync_exit(self)
    }
    
    func removePendingRequest(with id: PHImageRequestID) {
        performPendignRequestsChange {
            if let index = pendingRequests.index(of: id) {
                pendingRequests.remove(at: index)
            }
        }
    }

}

// MARK: Load request cancellation

extension AnyResource {
    
    func cancelLastRequest() {
        performPendignRequestsChange {
            guard let lastRequestID = pendingRequests.last else { return }
            
            PHImageManager.default().cancelImageRequest(lastRequestID)
            
            pendingRequests.removeLast()
        }
    }
    
}
