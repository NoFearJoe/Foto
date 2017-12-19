//
//  Album.swift
//  Foto
//
//  Created by Ilya Kharabet on 26.03.17.
//  Copyright © 2017 Mesterra. All rights reserved.
//

import Photos


public enum AlbumType {
    
    /// Album with a certain type of data. For example, album with all photos.
    case composite
    
    /// System album. For example, Faces or iCloud
    case system(subtype: PHAssetCollectionSubtype)
    
    /// User album. IMPORTANT: use Album.craete(title: completion:) before calling Album.init, otherwise data will not be fetched
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

/// A state indicating the presence or absence of actions performed with the album
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
    
    case action(type: ActionType)
    case noActions
    
    var description: String {
        switch self {
        case .noActions: return "No actions"
        case .action(let type): return type.description
        }
    }
    
}

extension AlbumState: Equatable {

    public static func ==(lhs: AlbumState, rhs: AlbumState) -> Bool {
        switch (lhs, rhs) {
        case (.noActions, .noActions): return true
        case (.action(let type1), .action(let type2)): return type1 == type2
        default: return false
        }
    }

}

extension AlbumState.ActionType: Equatable {

    public static func ==(lhs: AlbumState.ActionType, rhs: AlbumState.ActionType) -> Bool {
        switch (lhs, rhs) {
        case (.deletion, .deletion), (.fetching, .fetching), (.saving, .saving): return true
        default: return false
        }
    }

}



// MARK: - Album

public class Album<T: AnyResource> {

    var assetCollection: PHAssetCollection?
    let albumType: AlbumType
    
    var objects: [T] = [] {
        didSet {
            state = .noActions

            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.objectsRetrieved?(self.objects)
            }
        }
    }
    
    /// Called when new objects was retrieved. Performs in main queue
    public var objectsRetrieved: (([T]) -> Void)?
    
    /// Called when state was changed. Performs in main queue
    public var stateChanged: ((AlbumState) -> Void)?
    
    
    fileprivate let observer: AlbumFetchResultObserver<PHAsset>!
    fileprivate var fetchResult: PHFetchResult<PHAsset>? {
        didSet {
            observer.fetchResult = self.fetchResult
            
            guard let fetchResult = self.fetchResult else { return }
            
            self.objects = self.mapFetchResult(fetchResult: fetchResult)
        }
    }
    
    fileprivate var state: AlbumState = .noActions {
        didSet {
            if oldValue != state {
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    self.stateChanged?(self.state)
                }
            }
        }
    }
    
    fileprivate var lastFetchOptions: PHFetchOptions?
    
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "com.mesterra.foto.fetch")
    
    
    /**
     Creates new instanse of Album with specified album type. 
     
     IMPORTANT: if you pass AlbumType.custom, you need to call Album.craete(title: completion:) before calling this initializer.
     
     - Parameter type: Type of album
     */
    public init(type: AlbumType) {
        self.albumType = type
        
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
    
    
    /**
     Create new album with specified title. Type of this album will be AlbumType.custom.
     
     Call this method before Album(init: .custom(title: "some")).
     
     If album is already created nothing will happen
     
     - Parameter title: Title of album
     - Parameter completion: Completion closure
     - Parameter success: Returns true if an album was created successfully
     - Parameter error: Error
     */
    public class func create(title: String, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
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

// MARK: - Fetching

public extension Album {

    /**
     Performs last fetch
     */
    public func refetch() {
        fetch { options -> PHFetchOptions? in
            return self.lastFetchOptions
        }
    }
    
    /**
     Performs fetch of object with sorting by creation date
     
     - Parameter ascending: If true, objects starts with earliest date. Default false
     */
    public func fetchByCreationDate(ascending: Bool = false) {
        fetch { options -> PHFetchOptions? in
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
            
            return options
        }
    }
    
    /**
     Performs fetch with specified fetch options
     
     - Parameter optionsClosure: Provide default options for fetch request and returns final options
     - Parameter options: Default options for fetch request
     */
    public func fetch(with optionsClosure: @escaping (_ options: PHFetchOptions) -> PHFetchOptions?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            
            self.state = .action(type: .fetching)
            
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

// MARK: - Fetch result mapping

public extension Album {

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

// MARK: - Object deletion

extension Album: AnyResourceStore {
    
    /**
     Removes an object
     
     - Parameter object: Object to delete
     */
    public func remove(object: AnyResource) {
        remove(objects: [object])
    }
    
}

public extension Album {
    
    /**
     Removes array of objects
     
     - Parameter objects: Array of objects to delete
     */
    public func remove(objects: [AnyResource]) {
        state = .action(type: .deletion)

        PHPhotoLibrary.shared().performChanges({ () -> Void in
            let assets = objects.map { $0.asset }
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { [weak self] (success, error) -> Void in
            if !success {
                self?.state = .noActions
            }
        })
    }
    
    
    
    /**
     Removes an object at index
     
     - Parameter index: Index of object
     */
    public func remove(by index: Int) {
        if objects.indices.contains(index) {
            let object = objects[index]
            remove(object: object)
        }
    }
    
    /**
     Removes an object at indexes
     
     - Parameter indexes: Indexes of objects
     */
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

// MARK: - Object saving

public extension Album {

    /**
     Saves Data as image. If you pass no image data, nothing will happen
     
     - Parameter data: Image data
     */
    public func saveImage(data: Data) {
        state = .action(type: .saving)
        
        switch albumType {
        case .custom:
            // TODO: Test cases if data is not an image
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
            }, completionHandler: { [weak self] (success, error) -> Void in
                if !success {
                    self?.state = .noActions
                }
            })
        default:
            PHPhotoLibrary.shared().performChanges({ () -> Void in
                PHAssetCreationRequest.forAsset().addResource(with: PHAssetResourceType.fullSizePhoto, data: data, options: nil)
            }, completionHandler: { [weak self] (success, error) -> Void in
                if !success {
                    self?.state = .noActions
                }
            })
        }
    }

}


// MARK: - Library change observers

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
        
        if let newAssetCollection = changes.objectAfterChanges {
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
