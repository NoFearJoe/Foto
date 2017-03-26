//
//  Photo.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


public enum PhotoSubtype {
    case panorama
    case hdr
    case screenshot
    case live
    case depthEffect
    
    static func subtypes(from assetSubtypes: PHAssetMediaSubtype) -> [PhotoSubtype] {
        var subtypes: [PhotoSubtype] = []
        
        if assetSubtypes.contains(.photoPanorama) {
            subtypes.append(.panorama)
        }
        if assetSubtypes.contains(.photoHDR) {
            subtypes.append(.hdr)
        }
        if assetSubtypes.contains(.photoScreenshot) {
            subtypes.append(.screenshot)
        }
        if #available(iOS 9.1, *), assetSubtypes.contains(.photoLive) {
            subtypes.append(.live)
        }
        if #available(iOS 10.2, *), assetSubtypes.contains(.photoDepthEffect) {
            subtypes.append(.depthEffect)
        }
        
        return subtypes
    }
    
}

public enum BurstSelectionType {
    case none
    case userPick
    case autoPick
    case both
    
    init(burstSelectionTypes: PHAssetBurstSelectionType) {
        if burstSelectionTypes.contains(.userPick) && burstSelectionTypes.contains(.autoPick) {
            self = .both
        } else if burstSelectionTypes.contains(.userPick) {
            self = .userPick
        } else if burstSelectionTypes.contains(.autoPick) {
            self = .autoPick
        } else {
            self = .none
        }
    }
    
}


open class Photo: BaseGalleryObject {

    public struct BurstInfo {
        let representsBurst: Bool
        let burstIdentifier: String?
        let burstSelectionTypes: BurstSelectionType
    }
    
    
    lazy public var subtypes: [PhotoSubtype] = {
        return PhotoSubtype.subtypes(from: self.asset.mediaSubtypes)
    }()
    
    lazy public var burstInfo: BurstInfo = {
        return BurstInfo(representsBurst: self.asset.representsBurst,
                         burstIdentifier: self.asset.burstIdentifier,
                         burstSelectionTypes: BurstSelectionType(burstSelectionTypes: self.asset.burstSelectionTypes))
    }()
    
}


// MARK: Content loading

public extension Photo {

    public func loadImage(size: CGSize, contentMode: PHImageContentMode = .default, completion: @escaping (UIImage?) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.version = .current
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = true
        
        var requestID: PHImageRequestID = -1
        requestID = PHImageManager.default().requestImage(for: self.asset,
                                                              targetSize: size,
                                                              contentMode: contentMode,
                                                              options: requestOptions)
        { [weak self] (image, info) in
            self?.removePendingRequest(with: requestID)
            
            completion(image)
        }
        
        performPendignRequestsChange {
            pendingRequests.append(requestID)
        }
    }
    
    public func loadImageData(completion: @escaping (Data?) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.version = .current
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = true
        
        var requestID: PHImageRequestID = -1
        requestID = PHImageManager.default().requestImageData(for: self.asset,
                                                  options: requestOptions)
        { [weak self] (data, UTI, imageOrientation, info) in
            self?.removePendingRequest(with: requestID)
            
            completion(data)
        }
        
        performPendignRequestsChange {
            pendingRequests.append(requestID)
        }
    }
    
    @available(iOS 9.1, *)
    public func loadLivePhoto(size: CGSize, contentMode: PHImageContentMode = .default, completion: @escaping (PHLivePhoto?) -> Void) {
        let requestOptions = PHLivePhotoRequestOptions()
        requestOptions.version = .current
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = true
        
        var requestID: PHImageRequestID = -1
        requestID = PHImageManager.default().requestLivePhoto(for: self.asset,
                                                  targetSize: size,
                                                  contentMode: contentMode,
                                                  options: requestOptions)
        { [weak self] (livePhoto, info) in
            self?.removePendingRequest(with: requestID)
            
            completion(livePhoto)
        }
        
        performPendignRequestsChange {
            pendingRequests.append(requestID)
        }
    }

}
