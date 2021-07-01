//
//  PGL-CDFilterStack.swift
//  Glance
//
//  Created by Will on 11/30/18.
//  Copyright © 2018 Will. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import CoreImage
import Photos
import PhotosUI
import os
var PersistentContainer: NSPersistentCloudKitContainer = {
       /*
        The persistent container for the application. This implementation
        creates and returns a container, having loaded the store for the
        application to it. This property is optional since there are legitimate
        error conditions that could cause the creation of the store to fail.
       */
//       let container = NSPersistentContainer(name: "Surreality")
      let container = NSPersistentCloudKitContainer(name: "WillsFilterTool")

  

    //******* ONLY One time END


//    let container = NSPersistentContainer(name: "WillsFilterTool")
       container.loadPersistentStores(completionHandler: { (storeDescription, error) in
           if let error = error as NSError? {
               // Replace this implementation with code to handle the error appropriately.
               // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

               /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
//               fatalError("Unresolved error \(error), \(error.userInfo)")
            DispatchQueue.main.async {
                // put back on the main UI loop for the user alert
                let alert = UIAlertController(title: "Data Store Error", message: " \(error.localizedDescription)", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                    Logger(subsystem: LogSubsystem, category: LogCategory).notice("The userSaveErrorAlert \(error.localizedDescription)")
                }))
                let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
                myAppDelegate.displayUser(alert: alert)
            }
           }
       })
       return container
   }()

struct PGLStackType {
   var name: String
}

let StackTypeKey = "StackTypes"
// key for the AppUserDefaults instance of UserDefaults

enum saveHEIFError: Error {
    case nilReturn
    case otherSaveError
}

extension PGLFilterStack {

    convenience init(readName: String, createdDate: Date) {
        self.init()
        stackName = readName
        let removedFilter = removeDefaultFilter() // remove existing filters from the init()
//        NSLog("PGLFilterStack init has removed defaultFilter = \(String(describing: removedFilter))")
        readCDStack(titled: readName, createdDate: createdDate)
    }


        func on(cdStack: CDFilterStack) {
            // change this to a convience init.. caller does not need to create PGLFilterStack first

            storedStack = cdStack
            stackName = cdStack.title ?? "untitled"
            stackType = cdStack.type ?? "unTyped"
            if let thumbNailPGNImage = cdStack.thumbnail {
                thumbnail = UIImage(data: thumbNailPGNImage) // thumbnail is png format data aCDStack.thumbnail
            }

           exportAlbumIdentifier = cdStack.exportAlbumIdentifier
            exportAlbumName = cdStack.exportAlbumName
            let sortDescription = NSSortDescriptor(key: "stackPosition", ascending: true)
            let sortedFilter = cdStack.filters!.sortedArray(using: [sortDescription])
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGL-CDFilter PGLFilterStack init storedStack" )
            for aCDFilter in sortedFilter {
                // load stack to filter relationship

                if let myCDFilter = aCDFilter as? CDStoredFilter {
                    Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLFilterStack init storedStack on filter = \(String(describing: myCDFilter.ciFilterName))" )
//                    NSLog("PGLFilterStack filters on \(aCDFilter.stackPosition)")
                    guard let newSource = PGLSourceFilter.readPGLFilter(myCDFilter: myCDFilter)

                    else { return }
                    appendFilter(newSource)

                }
            }
        }



    func readCDStack(titled: String, createdDate: Date){

//        PersistentContainer.performBackgroundTask() { (moContext ) in
            let moContext = PersistentContainer.viewContext
            let request =  NSFetchRequest<CDFilterStack>(entityName: "CDFilterStack")
            // assume we are reading by title
            let titlePredicate = NSPredicate(format: "title == %@", titled)
            let datePredicate = NSPredicate(format: "created == %@", createdDate as CVarArg)
    //        let sortFiltersPredicate = NSSortDescriptor(key: #keyPath(CDFilterStack.filters.stackPosition), ascending: true)
            request.predicate = NSCompoundPredicate.init(andPredicateWithSubpredicates: [titlePredicate, datePredicate])
            request.fetchLimit = 1
    //        request.sortDescriptors = [sortFiltersPredicate]

            var readResults: [CDFilterStack]!
            do {  readResults = try moContext.fetch(request) }
            catch {  DispatchQueue.main.async {
                // put back on the main UI loop for the user alert
                let alert = UIAlertController(title: "Data Read Error", message: " \(error.localizedDescription)", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                    Logger(subsystem: LogSubsystem, category: LogCategory).notice("The userSaveErrorAlert alert \(error.localizedDescription)")
                }))
                let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
                myAppDelegate.displayUser(alert: alert)
                }
            }

            if let aCDStack = readResults.first {
                self.on(cdStack: aCDStack)
            }
//        }
    }

    func setToNewStack() {
        for filterIndex in 0..<activeFilters.count {
            let aFilter = activeFilters[filterIndex]
            aFilter.setToNewImageList()
            aFilter.storedFilter = nil
        }
        storedStack = nil
    }
    func writeCDStack(moContext: NSManagedObjectContext) -> CDFilterStack {
//        NSLog("PGLFilterStack #writeCDStack name = \(stackName)")

//        let moContext = PersistentContainer.viewContext

            if (storedStack == nil ) { // new stack needed
                storedStack = NSEntityDescription.insertNewObject(forEntityName: "CDFilterStack", into: moContext) as? CDFilterStack
                storedStack?.created = Date()
                }
                else { storedStack?.modified = Date()}
            storedStack?.title = stackName
            storedStack?.type = stackType
            storedStack?.exportAlbumName = exportAlbumName
            storedStack?.exportAlbumIdentifier = exportAlbumIdentifier

            storedStack?.thumbnail = stackThumbnail()  // data format of small png image

    //        for aFilter in activeFilters {
            for filterIndex in 0..<activeFilters.count {
                let aFilter = activeFilters[filterIndex]
                if aFilter.storedFilter == nil {
                    let theFilterStoredObject = aFilter.createCDFilterObject(moContext: moContext, stackPosition: Int16(filterIndex))
                    // moves images to cache to reduce storage
                    // does not need to add if the filter exists in the relation already
                    // storedStack?.addToFilters(theFilterStoredObject)
                    // add at the correct position !
                    storedStack?.addToFilters(theFilterStoredObject)
                    //storedStack?.insertIntoFilters(theFilterStoredObject, at: filterIndex)

                } else {
                    // further check on the relationship
                    aFilter.storedFilter?.stackPosition = Int16(filterIndex)
                        // always reset this for order changes

                    if aFilter.storedFilter?.stack == nil {
                        // make sure we have the order correct
                        // appends cdStoredfilter to the stack relationship

                        storedStack?.addToFilters(aFilter.storedFilter!)
                    }
                }
                aFilter.writeFilter(moContext: moContext) // handles imageparms move to cache etc..


            }
            return storedStack!  // force error if not set
    }

    func restoreCDstackImageCache() {
        // drill to all the filters and restoreImageCache after the moContext.save()
        for aFilter in activeFilters {
            aFilter.restoreImageInputsFromCache()
        }

    }

    func delete() {
        // delete this stack from the data store

//        PersistentContainer.performBackgroundTask() { (moContext ) in
        let moContext = PersistentContainer.viewContext
            if self.storedStack != nil {
                moContext.delete(self.storedStack!)
//        }
        }

    }
    func stackThumbnail() -> Data? {
        // output image in thumbnail size and png data format


        let outputImage = stackOutputImage(false)
        let uiOutput = UIImage(ciImage: outputImage )
//        return uiOutput.pngData() // big size

//         the code below produces a thumbnail that is too small.
        let magicNum: CGFloat  = 800.0  // 44.0 numerator for ratio to max dimension of the image
       let outputSize = uiOutput.size

        var ratio: CGFloat = 0
        ratio = magicNum / max(outputSize.width, outputSize.height)

        let smallSize = CGSize(width: (ratio * outputSize.width), height: (ratio * outputSize.height))
        let smallRect = CGRect(origin: CGPoint.zero, size: smallSize)

        UIGraphicsBeginImageContext(smallSize)
        uiOutput.draw(in: smallRect)


        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
      return thumbnail?.pngData()

    }

}
// ================= end extension PGLFilterStack ======================

extension PGLSourceFilter {
    // core data methods
    // MARK: CoreData

    class func readPGLFilter(myCDFilter: CDStoredFilter) -> PGLSourceFilter? {
        guard let filterBuilder = PGLFilterCategory.getFilterDescriptor(aFilterName: myCDFilter.ciFilterName!, cdFilterClass: myCDFilter.pglSourceFilterClass!)
            else { return nil }
         guard let newSource = filterBuilder.pglSourceFilter()
             else { return nil}

        newSource.localFilter = myCDFilter.ciFilter!
        newSource.storedFilter = myCDFilter
        newSource.resetAttributesToLocalFilter()
        if let parmImages = myCDFilter.input?.allObjects as? [CDParmImage] {
            // attach the cdParmImage to the matching filter attribute
            for aCDParmImage in parmImages {
                if let thisImageAttribute = newSource.attribute(nameKey: aCDParmImage.parmName!) as? PGLFilterAttributeImage {
                    thisImageAttribute.readCDParmImage(cdImageParm: aCDParmImage)
                }
            }
        }
        return newSource

    }

    func createCDFilterObject(moContext: NSManagedObjectContext, stackPosition: Int16) -> CDStoredFilter {
        // create cdFilter object
        // do not store filter image inputs in the CoreData..
        // saves storage memory - the localId will be saved and used to restore inputs
        // pglImageParms will handle the localId

        // get dictionary of attribute name and the current value in the filter

//        let moContext = PersistentContainer.viewContext

            if storedFilter == nil {
//                NSLog("PGLSourceFilter #cdFilterObject storedFilter insertNewObject \(String(describing: filterName))")
                storedFilter =  NSEntityDescription.insertNewObject(forEntityName: "CDStoredFilter", into: moContext) as? CDStoredFilter

            }
            storedFilter?.stackPosition = stackPosition
            storedFilter!.ciFilter = self.localFilter
            storedFilter!.ciFilterName = self.filterName
            storedFilter!.pglSourceFilterClass = self.classStringName()

            return storedFilter!
            // moContext save at the stack save

    }

    func writeFilter(moContext: NSManagedObjectContext) {
        // prepare image cache
        // create imageList
        // assumes createCDFilterObject has created the storedFilter if needed
//        NSLog("PGLSourceFilter #writeFilter filter \(String(describing: filterName))")
        imageInputCache = moveImageInputsToCache()
        createCDImageList(moContext: moContext) // creates for all the input parms

    }

    func moveImageInputsToCache() -> [String :CIImage?] {
        var localCache = [String : CIImage?]()
//        NSLog("PGLSourceFilter #moveImageInputsToCache filter \(String(describing: filterName))")


        for aImageKey in imageInputAttributeKeys {
//            NSLog("PGLSourceFilter #moveImageInputsToCache on \(aImageKey)")
            localCache[aImageKey] = valueFor(keyName: aImageKey) as? CIImage
            self.removeImageValue(keyName: aImageKey)
        }

        return localCache
    }

    func restoreImageInputsFromCache() {
        // from the filter var imageInputCache
//       NSLog("PGLSourceFilter #restoreImageInputsFromCache filter \(String(describing: filterName))")
        for (attributeName, image ) in imageInputCache {
            if let aCIImage = image {
                setImageValue(newValue: aCIImage, keyName: attributeName)
            }
            if let parm = attribute(nameKey: attributeName){
                if parm.hasFilterStackInput() {
                    // drill down to restore child stack filters too
                    let childStack = parm.inputStack
                    childStack?.restoreCDstackImageCache()
                }
            }

        }
        imageInputCache = [String :CIImage?]() // clear the cache
    }



    func removeOldImageList(imageParmName: String) {
        // 4EntityModel
        let myCDParmImages = readCDParmImages()
        // does not use the getCDParmImage(attribute:) method - that creates CDImageList if none exists..
        // we are deleting here.. don't create one to delete

        if let cdImageParm = myCDParmImages.first(where: {$0.parmName == imageParmName} ) {
            cdImageParm.inputAssets = nil // does this remove the related CDImageList row?
        }
    }

//    func readCDImageList(parentStack: PGLFilterStack)
    func setToNewImageList() {
        // set all of the core data vars to nil to save as new stack
        if let myImageParms = imageParms() {
            for anImageParm in myImageParms {
                if let childInputStack = anImageParm.inputStack {
                    childInputStack.setToNewStack() // will clear child filters
                }
                anImageParm.storedParmImage?.inputAssets = nil
                anImageParm.storedParmImage = nil
            }
        }

    }
    func createCDImageList(moContext: NSManagedObjectContext) {
        // 4EntityModel
        // create new CDImageList for every parm

        // remove - the source filter should not create the Image List
        // the ParmImage should control the Image List relationship

        if let myImageParms = imageParms() {
            for anImageParm in myImageParms {
                anImageParm.createNewCDImageParm(moContext: moContext)
                 // creates where relationship does not exist
            }
        }

    }

    func readCDParmImages() -> [CDParmImage] {
        // 4EntityModel
        // load all the cdParmImages
        if let result = storedFilter?.input?.allObjects as? [CDParmImage] {
            for aParmImage in result {
                if let cdChildStack = aParmImage.inputStack {
                    let pglChildStack = PGLFilterStack()
                    pglChildStack.on(cdStack: cdChildStack)

                }
            }
            return result
        } else { return [CDParmImage]() }

    }

    // MARK: PGLSourceFilter support


    func imageParms() -> [PGLFilterAttributeImage]? {
         // 4EntityModel
        // all parms that take an image as input

        if imageInputAttributeKeys.isEmpty {return nil }
        var imageAttributes = [PGLFilterAttributeImage]()

        for imageParmKey in imageInputAttributeKeys {
            if let thisImageAttribute = attribute(nameKey: imageParmKey) as? PGLFilterAttributeImage {
                imageAttributes.append(thisImageAttribute) }
            else { continue // to next element in the loop }
            }
        }
        return imageAttributes
    }

}  // ================ end extension PGLSourceFilter =========================

extension PGLFilterAttributeImage {

    func readCDParmImage(cdImageParm: CDParmImage) {
        // load relationships to the imageParm either input stack or Image List
        if let childStack = cdImageParm.inputStack  {
            let newPGLChildStack = PGLFilterStack()
            newPGLChildStack.on(cdStack: childStack)
            newPGLChildStack.parentAttribute = self
            self.inputStack = newPGLChildStack
                // in the UI inputStack is set with the PGLAppStack.addChildStackTo:(parm:)
                // Notice the didSet in inputStack: it hooks output of stack to input of the attribute
            setImageParmState(newState: ImageParm.inputChildStack)
        } else {
            // load relation inputAssets and attach an ImageList as input
            if let inputImageList = cdImageParm.inputAssets {
                let newImageList = PGLImageList(localAssetIDs: (inputImageList.assetIDs)!,albumIds: (inputImageList.albumIds!))
                newImageList.on(imageParm: self)
            }
        }
    }

    func createNewCDImageParm(moContext: NSManagedObjectContext) {
        // 4EntityModel
//        NSLog("PGLFilterAttributeImage #createNewCDImageParm filter \(String(describing: attributeName ))")
//        let moContext = PersistentContainer.viewContext

        if self.storedParmImage == nil {
            guard let newCDImageParm =  NSEntityDescription.insertNewObject(forEntityName: "CDParmImage", into: moContext) as? CDParmImage
                else {
                DispatchQueue.main.async {
                    // put back on the main UI loop for the user alert
                    let alert = UIAlertController(title: "Data Create Error", message: "Data creation failure ", preferredStyle: .alert)

                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                        Logger(subsystem: LogSubsystem, category: LogCategory).error("The userSaveErrorAlert Data Create Error")
                    }))
                    let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
                    myAppDelegate.displayUser(alert: alert)
                    }
                return
            }
            newCDImageParm.parmName = self.attributeName
            newCDImageParm.filter = self.aSourceFilter.storedFilter // creates relationship
            self.storedParmImage = newCDImageParm
        }

        // create related CDImageList
        if self.inputCollection != nil {
            if storedParmImage?.inputAssets == nil {
            guard let storedImageList =  NSEntityDescription.insertNewObject(forEntityName: "CDImageList", into: moContext) as? CDImageList
                else {
                DispatchQueue.main.async {
                    // put back on the main UI loop for the user alert
                    let alert = UIAlertController(title: "Data Create Error", message: "Data creation failure ", preferredStyle: .alert)

                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                        Logger(subsystem: LogSubsystem, category: LogCategory).error ("The userSaveErrorAlert Data Create Error.")
                    }))
                    let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
                    myAppDelegate.displayUser(alert: alert)
                    }
                return
            }
                storedParmImage?.inputAssets = storedImageList // sets up the relationship parm to inputAssets
            }
            if let imageListAssets = self.inputCollection?.imageAssets {
                storedParmImage?.inputAssets?.assetIDs = imageListAssets.map({$0.localIdentifier})
                storedParmImage?.inputAssets?.albumIds = imageListAssets.map({$0.albumId})
                }
            }
        if self.inputStack != nil {
            // a child stack exists
            if self.storedParmImage?.inputStack == nil {
                // create a cdFilterStack for the child stack input to the parm
                if let childCDStack = self.inputStack?.writeCDStack(moContext: moContext) {
                    self.storedParmImage?.inputStack = childCDStack
                }
                    // store the relationship


            }
        }


    }

}
// ================ end extension PGLFilterAttributeImage =========================

// ================ start extension PGLImageList  =========================
extension PGLImageList {
    func on(imageParm: PGLFilterAttributeImage) {
        self.setUserSelection(toAttribute: imageParm)
        imageParm.setImageCollectionInput(cycleStack: self)
    }
}

// ================ end extension PGLImageList  =========================

// ================ start extension PGLAppStack =========================
extension PGLAppStack {
     func firstStack() -> PGLFilterStack? {
        if pushedStacks.isEmpty {
          return  viewerStack
        } else { return pushedStacks.first}
    }

    func rollbackStack() {
        // removes unsaved changes from the NSManagedObjectContext
        let moContext = PersistentContainer.viewContext
        moContext.rollback()

    }

    func writeCDStacks(){
        // store starting from the top level
        // each stack will write in turn as it is referenced
        // do not need to iterate the collection

        // stop the display timer while writing the stacks to core data
        // filter image inputs are nil for core data then restored on completion
        

//    PersistentContainer.performBackgroundTask() { (moContext ) in
        let moContext = PersistentContainer.viewContext
        if let initialStack = self.firstStack() {
         _ = initialStack.writeCDStack(moContext: moContext)
            // filter images are moved to a cache before the save
//        do {
//                try  moContext.save()  // saves to parent viewContext
//            }
//            catch { self.userSaveErrorAlert(withError: error)}
////        }
    }

    let viewMoContext = PersistentContainer.viewContext
    if viewMoContext.hasChanges {
    do {
        try viewMoContext.save() // this parent context saves to the db
//        NSLog("PGLAppStack #writeCDStacks save called")
        } catch {
            Logger(subsystem: LogSubsystem, category: LogCategory).error("moContext.save error \(error.localizedDescription)")

                // put back on the main UI loop for the user alert
                self.userSaveErrorAlert(withError: error)


            }


      // now restore all the cached input images
        if let initialStack = firstStack() {
         initialStack.restoreCDstackImageCache()
            // bring back the image cache to filter inputs after save runs
            }
        }
    }


    func userSaveErrorAlert(withError: Error) {
        DispatchQueue.main.async {
            // all UI needs to be in the main queue including creation of UIAlertController
        let alert = UIAlertController(title: "Save Error", message: "Try again with 'Save As' command", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            Logger(subsystem: LogSubsystem, category: LogCategory).error ("The userSaveErrorAlert \(withError.localizedDescription)")
        }))

        let userAlertNotification =  Notification(name: PGLUserAlertNotice, object: nil , userInfo: ["alertController" : alert])
        NotificationCenter.default.post(userAlertNotification)
        }
    }


    func setToNewStack() {
        // save as.. command..
        // reset core data vars to nil for save as new records
        rollbackStack() // discards any coredata changes
            // or update to persistant state

        firstStack()?.setToNewStack() // create new
    }

    func saveStack(metalRender: Renderer) {

//        NSLog("PGLAppStack #saveStack start")
        let serialQueue = DispatchQueue(label: "queue", qos: .utility, attributes: [], autoreleaseFrequency: .workItem, target: nil)
        serialQueue.async {
            let targetStack = self.firstStack()!
//            NSLog("PGLAppStack #saveStack serialQueue execution start")
            DoNotDrawWhileSave = true
            defer { DoNotDrawWhileSave = false } // executes at the end of this function
            if targetStack.shouldExportToPhotos {
               self.saveToPhotosLibrary(stack: targetStack, metalRender: metalRender)
               // call first so the albumIdentifier can be stored
                // does a performChangesAndWait  sync
            }
//           NSLog("PGLAppStack #saveStack calls writeCDStacks")
            self.writeCDStacks()

        }
    }

    func saveToPhotosLibrary( stack: PGLFilterStack, metalRender: Renderer ) {
                // NOT called if targetStack.shouldExportToPhotos = false
                // check if the album exists..)
               // save the output of this stack to the photos library
                // Create a new album with the entered title.
              
        var assetCollection: PHAssetCollection?
        var heifData: Data?

//        NSLog("saveToPhotosLibrary = \(String(describing: stack.exportAlbumIdentifier))")
          if let existingAlbumId = stack.exportAlbumIdentifier {
               let fetchResult  = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [existingAlbumId], options: nil)
               assetCollection = fetchResult.firstObject
//                NSLog("PGLImageController #saveToPhotosLibrary append to existing assetCollection \(String(describing: assetCollection))")
          } else {
               // check for existing albumName
           if let aAlbumExportName = stack.exportAlbumName { // maybe nil

               // find it or or create it.
               // leave assetCollection as nil to create

             // fatalError( "PHAssetCollection needs to search for a matching album title #saveToPhotosLibrary")
               // how to do this???
            let albums = stack.getAlbums()
            let matching = stack.filterAlbums(source: albums, titleString: aAlbumExportName)
            if matching.count > 0 {
                   assetCollection = matching.last!.assetCollection
               }
            }
           }


        if stack.shouldExportToPhotos {
               // Add the asset to the photo library
                // album name may not be entered or used if limited photo library access
            do {  heifData = try metalRender.captureHEIFImage() }

            catch {
                Logger(subsystem: LogSubsystem, category: LogCategory).error ("saveToPhotosLibrary metalRender failed at captureHEIFImage")
                userSaveErrorAlert(withError: error)
                return
            }
            do { try PHPhotoLibrary.shared().performChangesAndWait( {
                let creationRequest = PHAssetCreationRequest.forAsset()
                let fileNameOption = PHAssetResourceCreationOptions()
                fileNameOption.originalFilename = stack.stackName
                creationRequest.addResource(
                    with: PHAssetResourceType.photo,
                    data: heifData!,
                    options: fileNameOption)

//                            PHAssetChangeRequest.creationRequestForAsset(from: uiImageOutput)
//                            NSLog("PGLAppStack #saveToPhotosLibrary AssetChangeRequest = \(creationRequest)")
                       // either get or create the target album

                        if ( assetCollection == nil ) && ( stack.exportAlbumName != nil) {
                           // new collection
                           let assetCollectionRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: stack.exportAlbumName ?? "exportAlbum")
                           assetCollectionRequest.addAssets([creationRequest.placeholderForCreatedAsset!] as NSArray)
                           stack.exportAlbumIdentifier = assetCollectionRequest.placeholderForCreatedAssetCollection.localIdentifier
//                            NSLog("PGLAppStack #saveToPhotosLibrary new assetCollectionRequest = \(assetCollectionRequest)")

                       } else {
                           // asset collection exists
                        if assetCollection != nil {
                            let addAssetRequest = PHAssetCollectionChangeRequest(for: assetCollection!)
                            addAssetRequest?.addAssets([creationRequest.placeholderForCreatedAsset!] as NSArray)
//                            NSLog("PGLAppStack #saveToPhotosLibrary existing assetCollection adds = \(String(describing: addAssetRequest))")
                        }
                       }

                      } )
            } catch  { userSaveErrorAlert(withError: error)}

        }


           }

}
// ================ end extension PGLAppStack =========================