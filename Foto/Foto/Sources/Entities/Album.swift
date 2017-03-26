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


public enum AlbumState {
    
    public enum ActionType {
        case deletion
        case fetching
        case saving
        
        var description: String {
            switch self {
            case .deletion: return "Deletion"
            case .fetching: return "Fetching"
            case .saving: return "Saving"
            }
        }
        
    }
    
    case process(type: ActionType)
    case idle
    
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .process(let type): return type.description
        }
    }
    
}


// MARK: Album

open class Album<T: AnyResource> {

    var assetCollection: PHAssetCollection?
    let albumType: AlbumType
    
    var objects: [T] = [] {
        didSet {
            state = .idle

            objectsRetrieved?(objects)
        }
    }
    
    
    public var objectsRetrieved: (([T]) -> Void)?
    public var stateChanged: ((AlbumState) -> Void)?
    
    
    fileprivate let observer: AlbumFetchResultObserver<PHAsset>!
    fileprivate var fetchResult: PHFetchResult<PHAsset>? {
        didSet {
            observer.fetchResult = self.fetchResult
            
            guard let fetchResult = self.fetchResult else { return }
            
            self.objects = self.mapFetchResult(fetchResult: fetchResult)
        }
    }
    
    fileprivate var state: AlbumState = .idle {
        didSet {
            stateChanged?(state)
        }
    }
    
    fileprivate var lastFetchOptions: PHFetchOptions?
    
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
    
    
    public class func createAlbum(title: String, completion: @escaping (Bool, Error?) -> Void) {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", title)
        let assetCollection = PHAssetCollection.fetchAssetCollections(with: AlbumType.custom(title: title).collectionType,
                                                                      subtype: .any,
                                                                      options: options).firstObject
        
        if assetCollection == nil {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            }, completionHandler: { (success, error) in
                completion(success, error)
            })
        } else {
            completion(true, nil)
        }
    }
    
    
    func fetchResultChanged(_ newFetchResult: PHFetchResult<PHAsset>) {
        queue.async { [weak self] in
            self?.fetchResult = newFetchResult
        }
    }

}

// MARK: Fetching

extension Album {

    public func refetch() {
        fetch { options -> PHFetchOptions? in
            return self.lastFetchOptions
        }
    }
    
    public func fetchByCreationDate(ascending: Bool = false) {
        fetch { options -> PHFetchOptions? in
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
            
            return options
        }
    }
    
    
    public func fetch(with optionsClosure: @escaping (PHFetchOptions) -> PHFetchOptions?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            
            self.state = .process(type: .fetching)
            
            let defaultOptions = PHFetchOptions()
            if T.self != AnyResource.self {
                defaultOptions.predicate = NSPredicate(format: "mediaType == %d", T.mediaType.rawValue)
            }
            
            let options = optionsClosure(defaultOptions)
            
            self.lastFetchOptions = options
            
            switch self.albumType {
            case .composite:
                self.fetchResult = PHAsset.fetchAssets(with: T.mediaType, options: options)
            default:
                if let collection = self.assetCollection {
                    self.fetchResult = PHAsset.fetchAssets(in: collection, options: options)
                }
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
                if let object = Photo(asset: asset, store: self) as? T {
                    acc.append(object)
                } else if let object = AnyResource(asset: asset, store: self) as? T {
                    acc.append(object)
                }
            case .video:
                if let object = Video(asset: asset, store: self) as? T {
                    acc.append(object)
                } else if let object = AnyResource(asset: asset, store: self) as? T {
                    acc.append(object)
                }
            default: break
            }
        })
        
        return acc
    }

}

// MARK: Object deletion

extension Album: AnyResourceStore {
    
    public func remove(objects: [AnyResource]) {
        state = .process(type: .deletion)

        PHPhotoLibrary.shared().performChanges({ () -> Void in
            let assets = objects.map { $0.asset }
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { [weak self] (success, error) -> Void in
            if !success {
                self?.state = .idle
            }
        })
    }
    
    public func remove(object: AnyResource) {
        remove(objects: [object])
    }
    
    public func remove(by index: Int) {
        if objects.indices.contains(index) {
            let object = objects[index]
            remove(object: object)
        }
    }
    
    public func removeAll(by indexes: [Int]) {
        let objects: [T] = indexes.flatMap { index in
            if self.objects.indices.contains(index) {
                return self.objects[index]
            }
            return nil
        }
        
        remove(objects: objects)
    }

}

// MARK: Object saving

extension Album {

    public func saveImage(data: Data) {
        state = .process(type: .saving)
        
        switch albumType {
        case .custom:
            PHPhotoLibrary.shared().performChanges({ [weak self] () -> Void in
                if let image = UIImage(data: data) {
                    let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    assetRequest.creationDate = Date()
                    let assetPlaceholder = assetRequest.placeholderForCreatedAsset
                    if let assets = self?.fetchResult {
                        if let collection = self?.assetCollection {
                            let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection, assets: assets)
                            if let placeholder = assetPlaceholder {
                                albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
                            }
                        }
                    }
                }
            }, completionHandler: nil)
        default:
            PHPhotoLibrary.shared().performChanges({ () -> Void in
                PHAssetCreationRequest.forAsset().addResource(with: PHAssetResourceType.fullSizePhoto, data: data, options: nil)
            }, completionHandler: { [weak self] (success, error) -> Void in
                if !success {
                    self?.state = .idle
                }
            })
        }
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
