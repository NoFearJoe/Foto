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


// MARK: - Video

open class Video: AnyResource {

    override public class var mediaType: PHAssetMediaType { return .video }
    
    /// Subtypes of Video. For example, Timelapsed or Streamed
    lazy var subtypes: [VideoSubtype] = {
        return VideoSubtype.subtypes(from: self.asset.mediaSubtypes)
    }()
    
    /// Video duration
    lazy var duration: TimeInterval = {
        return self.asset.duration
    }()

}

// MARK: - Content loading

extension Video {
 
    /**
     Requests video with specified queality
     
     - Parameter quelity: Target quality of video
     - Parameter completion: Completion closure
     - Parameter playerItem: Loaded player item or nil
     */
    func loadVideo(quality: PHVideoRequestOptionsDeliveryMode = .automatic,
                   completion: @escaping (_ item: AVPlayerItem?) -> Void) {
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
