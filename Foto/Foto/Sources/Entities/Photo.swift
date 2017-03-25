//
//  Photo.swift
//  Foto
//
//  Created by Ilya Kharabet on 25.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


enum PhotoSubtype {
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


open class Photo: BaseGalleryObject {

    lazy var subtypes: [PhotoSubtype] = {
        return PhotoSubtype.subtypes(from: self.asset.mediaSubtypes)
    }()

}
