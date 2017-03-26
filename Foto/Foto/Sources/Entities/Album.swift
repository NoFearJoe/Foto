//
//  Album.swift
//  Foto
//
//  Created by Ilya Kharabet on 26.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


public enum AlbumType {
    case system(subtype: PHAssetCollectionSubtype)
    case custom(title: String)
    
    var collectionType: PHAssetCollectionType {
        switch self {
        case .system(let subtype):
            switch subtype {
            case .albumRegular, .albumSyncedEvent, .albumSyncedFaces, .albumSyncedAlbum, .albumImported:
                return .album
            case .albumCloudShared, .albumMyPhotoStream:
                return .album
            default:
                return .smartAlbum
            }
        case .custom:
            return .album
        }
    }
    
}


open class Album<T: BaseGalleryObject> {

    let assetCollection: PHAssetCollection?
    
    
    var objects: [T] = []
    
    
    fileprivate let observer: AlbumFetchResultObserver<PHAsset>
    fileprivate var fetchResult: PHFetchResult<PHAsset>? {
        didSet {
            observer.fetchResult = self.fetchResult
        }
    }
    
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "com.mesterra.foto.fetch")
    
    
    public init(albumType: AlbumType) {
        switch albumType {
        case .system(let subtype):
            assetCollection = PHAssetCollection.fetchAssetCollections(with: albumType.collectionType,
                                                                      subtype: subtype,
                                                                      options: nil).firstObject
        case .custom(let title):
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "title = %@", title)
            assetCollection = PHAssetCollection.fetchAssetCollections(with: albumType.collectionType,
                                                                      subtype: .any,
                                                                      options: options).firstObject
        }
        
        observer = AlbumFetchResultObserver(fetchResult: nil)
        observer.fetchResultChanged = fetchResultChanged
        PHPhotoLibrary.shared().register(observer)
    }
    
    
    public func fetch(options: PHFetchOptions? = nil, completion: (([T]) -> Void)?) {
        queue.async { [weak self] in
            defer {
                completion?(self?.objects ?? [])
            }
            
            guard let `self` = self, let collection = self.assetCollection else { return }
            
            self.fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            
            guard let fetchResult = self.fetchResult else { return }
            
            self.objects = self.mapFetchResult(fetchResult: fetchResult)
        }
    }
    
    func mapFetchResult(fetchResult: PHFetchResult<PHAsset>) -> [T] {
        var acc: [T] = []
        
        fetchResult.enumerateObjects({ (asset, index, stop) in
            switch asset.mediaType {
            case .image:
                if let object = Photo(asset: asset) as? T {
                    acc.append(object)
                } else if let object = BaseGalleryObject(asset: asset) as? T {
                    acc.append(object)
                }
            case .video:
                if let object = Video(asset: asset) as? T {
                    acc.append(object)
                } else if let object = BaseGalleryObject(asset: asset) as? T {
                    acc.append(object)
                }
            default: break
            }
        })
        
        return acc
    }
    
    
    func fetchResultChanged(_ newFetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = newFetchResult
    }

}

class AlbumObserver: NSObject, PHPhotoLibraryChangeObserver {
    
    let assetCollection: PHAssetCollection?
    
    
    var assetCollectionChanged: ((PHAssetCollection) -> Void)?
    
    
    init(assetCollection: PHAssetCollection?) {
        self.assetCollection = assetCollection
        
        super.init()
    }
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let collection = assetCollection else { return }
        guard let changes = changeInstance.changeDetails(for: collection) else { return }
        
        if let newAssetCollection = changes.objectAfterChanges as? PHAssetCollection {
            assetCollectionChanged?(newAssetCollection)
        }
    }

}

class AlbumFetchResultObserver<T: PHObject>: NSObject, PHPhotoLibraryChangeObserver {

    var fetchResult: PHFetchResult<T>?
    
    
    var fetchResultChanged: ((PHFetchResult<T>) -> Void)?
    
    
    init(fetchResult: PHFetchResult<T>?) {
        self.fetchResult = fetchResult
        
        super.init()
    }
    
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = self.fetchResult else { return }
        guard let changes = changeInstance.changeDetails(for: fetchResult) else { return }
        
        let newFetchResult = changes.fetchResultAfterChanges
        
        fetchResultChanged?(newFetchResult)
    }

}
