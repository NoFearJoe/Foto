//
//  AnyResource.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


public enum ResourceSource {
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
    
    public var canDelete: Bool {
        return self != .iTunes
    }
    
    public var canEdit: Bool {
        return self == .library
    }
    
}


protocol AnyResourceStore {
    func remove(object: AnyResource)
}


// MARK: - Any resource

/// Base class of gallery object.
public class AnyResource {

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
    lazy public var source: ResourceSource = {
        return ResourceSource(sourceType: self.asset.sourceType)
    }()
    
    lazy public var filename: String? = {
        return self.asset.value(forKey: "filename") as? String
    }()
    
    /// Pixel size of object
    lazy public var size: CGSize = {
        return CGSize(width: self.asset.pixelWidth, height: self.asset.pixelHeight)
    }()
    
    /// Creation date of object
    lazy public var creationDate: Date? = {
        return self.asset.creationDate
    }()
    
    /// Modification date of object
    lazy public var modificationDate: Date? = {
        return self.asset.modificationDate
    }()
    
    /// The location saved with the object
    lazy public var location: CLLocation? = {
        return self.asset.location
    }()
    
    /// A boolean value that indicates whether the user has hidden the object
    lazy public var isHidden: Bool = {
        return self.asset.isHidden
    }()
    
    /// A Boolean value that indicates whether the user has marked the asset as a favorite
    lazy public var isFavorite: Bool = {
        return self.asset.isFavorite
    }()

}

// MARK: - Object methods

extension AnyResource {

    /**
     Checks that operation can be performed
     
     - Parameter editOperation: Operation
     */
    public func canPerform(_ editOperation: PHAssetEditOperation) -> Bool {
        return asset.canPerform(editOperation)
    }
    
    /**
     Removes itself
     */
    public func remove() {
        store.remove(object: self)
    }

}


// MARK: - Pending requests managing

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

// MARK: - Load request cancellation

extension AnyResource {
    
    public func cancelLastRequest() {
        performPendignRequestsChange {
            guard let lastRequestID = pendingRequests.last else { return }
            
            PHImageManager.default().cancelImageRequest(lastRequestID)
            
            pendingRequests.removeLast()
        }
    }
    
}

// MARK: - Hashable

extension AnyResource: Hashable {
    
    public static func ==(lhs: AnyResource, rhs: AnyResource) -> Bool {
        return lhs.asset == rhs.asset
    }
    
    public var hashValue: Int {
        return asset.hashValue
    }
    
}
