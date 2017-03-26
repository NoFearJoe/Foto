//
//  Album.swift
//  Foto
//
//  Created by Ilya Kharabet on 26.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


public enum AlbumType {
    case composite
    case system(subtype: PHAssetCollectionSubtype)
    case custom(title: String)
    
    var collectionType: PHAssetCollectionType {
        switch self {
        case .composite: return .album
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

// MARK: Album

open class Album<T: AnyResource> {

    let assetCollection: PHAssetCollection?
    let albumType: AlbumType
    
    var objects: [T] = [] {
        didSet {
            objectsRetrieved?(objects)
        }
    }
    
    
    public var objectsRetrieved: (([T]) -> Void)?
    
    
    fileprivate let observer: AlbumFetchResultObserver<PHAsset>
    fileprivate var fetchResult: PHFetchResult<PHAsset>? {
        didSet {
            observer.fetchResult = self.fetchResult
            
            guard let fetchResult = self.fetchResult else { return }
            
            self.objects = self.mapFetchResult(fetchResult: fetchResult)
        }
    }
    
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "com.mesterra.foto.fetch")
    
    
    public init(albumType: AlbumType) {
        self.albumType = albumType
        
        switch albumType {
        case .composite:
            assetCollection = nil
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
    
    
    func fetchResultChanged(_ newFetchResult: PHFetchResult<PHAsset>) {
        queue.async { [weak self] in
            self?.fetchResult = newFetchResult
        }
    }

}

// MARK: Fetching

extension Album {

    public func fetchByCreationDate(ascending: Bool = false) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
        if T.self != AnyResource.self {
            options.predicate = NSPredicate(format: "mediaType == %d", T.mediaType.rawValue)
        }
        
        fetch(options: options)
    }
    
    
    public func fetch(options: PHFetchOptions? = nil) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            
            switch self.albumType {
            case .composite:
                if let collection = self.assetCollection {
                    self.fetchResult = PHAsset.fetchAssets(in: collection, options: options)
                }
            default:
                self.fetchResult = PHAsset.fetchAssets(with: T.mediaType, options: options)
            }
        }
    }

}

// MARK: Fetch result mapping

extension Album {

    func mapFetchResult(fetchResult: PHFetchResult<PHAsset>) -> [T] {
        var acc: [T] = []
        
        fetchResult.enumerateObjects({ (asset, index, stop) in
            switch asset.mediaType {
            case .image:
                if let object = Photo(asset: asset) as? T {
                    acc.append(object)
                } else if let object = AnyResource(asset: asset) as? T {
                    acc.append(object)
                }
            case .video:
                if let object = Video(asset: asset) as? T {
                    acc.append(object)
                } else if let object = AnyResource(asset: asset) as? T {
                    acc.append(object)
                }
            default: break
            }
        })
        
        return acc
    }

}


// MARK: Library change observers

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
