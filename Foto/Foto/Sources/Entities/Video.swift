//
//  Video.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


enum VideoSubtype {
    case streamed
    case highFrameRate
    case timelapsed

    static func subtypes(from assetSubtypes: PHAssetMediaSubtype) -> [VideoSubtype] {
        var subtypes: [VideoSubtype] = []
        
        if assetSubtypes.contains(.videoStreamed) {
            subtypes.append(.streamed)
        }
        if assetSubtypes.contains(.videoHighFrameRate) {
            subtypes.append(.highFrameRate)
        }
        if assetSubtypes.contains(.videoTimelapse) {
            subtypes.append(.timelapsed)
        }
        
        return subtypes
    }
    
}


open class Video: BaseGalleryObject {

    lazy var subtypes: [VideoSubtype] = {
        return VideoSubtype.subtypes(from: self.asset.mediaSubtypes)
    }()
    
    lazy var duration: TimeInterval = {
        return self.asset.duration
    }()

}

// MARK: Content loading

extension Video {
 
    func loadVideo(quality: PHVideoRequestOptionsDeliveryMode = .automatic, completion: @escaping (AVPlayerItem?) -> Void) {
        let requestOptions = PHVideoRequestOptions()
        requestOptions.version = .current
        requestOptions.deliveryMode = quality
        requestOptions.isNetworkAccessAllowed = true
        
        var requestID: PHImageRequestID = -1
        requestID = PHImageManager.default().requestPlayerItem(forVideo: self.asset,
                                                               options: requestOptions,
                                                               resultHandler:
        { [weak self] (playerItem, info) in
            self?.removePendingRequest(with: requestID)
            
            completion(playerItem)
        })
        
        performPendignRequestsChange {
            pendingRequests.append(requestID)
        }
    }
    
}
