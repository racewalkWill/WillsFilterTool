//
//  PGLFilterStack.swift
//  PictureGlance
//
//  Created by Will on 3/18/17.
//  Copyright © 2017 Will. All rights reserved.
//

import Foundation
import CoreImage
import UIKit
import Photos
import PhotosUI
import os

// let defaultFilterName = "DistortionDemo"
// let defaultFilterName = "CIDepthOfField"
//let defaultFilterName = "CISourceInCompositing"
// let defaultFilterName = "CILinearGradient"
//let defaultFilterName = "CIAdditionCompositing"
//let defaultFilterName = "CIDissolveTransition"
 let defaultFilterName = kPImages


//let defaultFilterPosition = PGLFilterCategoryIndex(category: 6, filter: 0, catCodeName: "CICategoryCompositeOperations", filtCodeName: defaultFilterName)
//let defaultFilterPosition = PGLFilterCategoryIndex(category: 10, filter: 4, catCodeName: "CICategoryTransition", filtCodeName: defaultFilterName)
let defaultFilterPosition = PGLFilterCategoryIndex(category: 11, filter: 13, catCodeName: "CICategoryTransition", filtCodeName: defaultFilterName)



class PGLFilterStack  {
    // when the filter is changed - keep the old one until the new filter is applied
    // remove the apply logic.. do not keep the old one until applied.. one less button
    // March 9, 2021 Modified assumption that there is always at least one filter
    //  now stack may have no filters. isEmpty
    
   
    let  kFilterSettingsKey = "FilterSettings"
    let  kFilterOrderKey = "FilterOrder"

    var activeFilters = [PGLSourceFilter]()  // make private?
   
    var cropRect: CGRect { get
    {   return CGRect(x: 0, y: 0, width: TargetSize.width, height: TargetSize.height)

        }
    }

    var activeFilterIndex = 0


    var stackName:String = ""  // Date().description(with: Locale.current)
    var parentAttribute: PGLFilterAttribute?

//    var parentStack: PGLFilterStack?
    lazy var imageCIContext: CIContext = {return Renderer.ciContext}()

    var frameValueDeltas = PGLFilterChange()
    var storedStack: CDFilterStack? // managedObject write/read to Core Data
    var thumbnail: UIImage? //  for Core Data store

    var stackType = "type"
    var exportAlbumName: String?
    var exportAlbumIdentifier: String?
    var shouldExportToPhotos = false // default
    var stackMode = FilterChangeMode.add
        // StackController will change this to .replace if swipe cell command "Change" runs



@IBInspectable  var useOldImageFeedback = false
@IBInspectable  var doPrintCropClamp = false
    // set to true to use the old image input
    // in the debugger add expression self.doPrintCropClamp = true
    // need to add a break to open the debugger

    // MARK: Init default
    init(){

//        setStartupDefault()

    }
    // let defaultImageName = "shoreline"
    // let defaultImageName = "GridImage"

    func setStartupDefault() {
//        setDefault(initialImage: PGLTestImage.gridImage(withSize: CGSize(width: 791.5, height: 834.0)) ) //(0.0, 0.0, 791.5, 834.0)
//        let startingImage = (CIImage(image: (UIImage(named: "John+Ann" ))!))!
//        let johnAnnId = "ABB0A167-F79A-4916-9172-8ADC8377EF0E/L0/001"
            // get more ids by a break at PGLFilterAttribute setImageCollectionInput(cycleStack: PGLImageList)
            // in the futureit would be good to select the users favorites..
            // have an option to also pull a saved collection from the data store.. need to keep the name in some app attributes.
        let startImageList = PGLImageList(localAssetIDs: [String](), albumIds: [String]()  )
        let startingFilter = (PGLFilterDescriptor(defaultFilterName, PGLTransitionFilter.self))!


        setDefault(initialList: startImageList   , filterDescriptor: startingFilter ) // with nil parms uses defaults in setDefault declaration

    }

    func setDefault(initialList: PGLImageList,
                    filterDescriptor: PGLFilterDescriptor ) {

        if let filter = filterDescriptor.pglSourceFilter() {
            let inputAttribute = filter.getInputImageAttribute()
            inputAttribute?.setImageCollectionInput(cycleStack: initialList)

            filter.uiPosition = defaultFilterPosition
//            filter.setCIContext(detectorContext: imageCIContext)  // imageCIContext is set by the MetalController viewDidLoad
            appendFilter(filter)
//            NSLog("PGLFilterStack #setDefault image color space = \(String(describing: initialImage.colorSpace))")
        } else
        {
            Logger(subsystem: LogSubsystem, category: LogCategory).error("PGLFilterStack FAILED setDefault")
        }

    }


    // MARK: Filter access/move
    func hasAnimationFilter() -> Bool {
      return  activeFilters.contains { (aFilter: PGLSourceFilter) -> Bool in
            aFilter.hasAnimation
        }
    }
    func filterAt(tabIndex: Int) -> PGLSourceFilter {
        if( ( activeFilterIndex >= 0 )
            //            && (0 <= tabIndex )
                        && (tabIndex < activeFilters.count)
            // two different errors don't tackle both in same method
            // activeFilterIndex = - 1 is first filter was removed
            // so start over with default
            )
        { return activeFilters[tabIndex]
        } else {
            //            setDefault()
            return activeFilters[0]
        }
    }
    func moveActiveAhead() {
        //advance activeFilterIndex
        activeFilterIndex = min(activeFilterIndex + 1, activeFilters.count - 1) // zero based array
        // don't advance past the last one
    }

    func moveActiveBack() {
        //advance activeFilterIndex
        activeFilterIndex = max(activeFilterIndex - 1, 0)
        // don't advance past the last one
    }

//    func stackNextFilter() {
//        if (activeFilterIndex == activeFilters.count - 1) {
//           addFilterAfter()
//
//        } else {
//            moveActiveAhead()
//        }
//    }

    func firstFilterIsActive() -> Bool {
        return activeFilterIndex == 0
    }

    func lastFilterIsActive() -> Bool {
        return activeFilterIndex == (activeFilters.count - 1)
    }

    // MARK: Add/Remove filters

    func isEmptyStack() -> Bool {
        return activeFilters.isEmpty
    }

    func stackFilterName(_ forFilter: PGLSourceFilter, index: Int?) -> (String) {
        // answer filter number , filter name , and arrow point chars
        // "2 Source In ->"
        let positionNumber =  1 + (index ?? activeFilterIndex) // zero based array
        let positionString = "\(positionNumber)"
        let answer = (positionString + " " + forFilter.filterName + "->")
//        NSLog("PGLFilterStack #stackFilterName = \(answer)")
        return answer
    }

//    func addFilterAfter()  {
//        if isEmptyStack() {
//            // set default filter
////            setStartupDefault()
//            return
//        }
//        let currentFilter = activeFilters[activeFilterIndex]
//        let currentFilterClass = type(of: currentFilter) // create the correct subclass of PGLSourceFilter
//        if let newInstance = currentFilterClass.init(filter: currentFilter.filterName, position: currentFilter.uiPosition ) {
//            newInstance.setInput(image: currentFilter.inputImage(), source: currentFilter.sourceDescription(attributeKey: kCIInputImageKey))
//            // do subclasses of PGLSourceFilter have other vars to set??
//        addFilterAfter(newFilter: newInstance)
//        }
//
//
//    }

//    func addFilterAfter(newFilter: PGLSourceFilter) {
//        // assumes activeFilterIndex is set to the endingPoint
////        moveActiveAhead()
////        moveInputsFrom(activeFilters[activeFilterIndex], newFilter)
//        let nextFilterIndex = activeFilterIndex + 1
//        if lastFilterIsActive() {
//            // appending so output of newFilter does not go to input of next filter
//            // and there are no other image parms to also connect
//            newFilter.setInput(image: currentFilter().outputImage(), source: stackFilterName(currentFilter(), index: nextFilterIndex) )
//              // and set output of newClone to the input of the next activeFilter
//            newFilter.setSourceFilter(sourceLocation: (source: self, at: nextFilterIndex), attributeKey: kCIInputImageKey)
//            activeFilters.insert(newFilter, at: nextFilterIndex)
//            activeFilterIndex = nextFilterIndex
//        } else {
//             let nextFilter = activeFilters[nextFilterIndex]
//             moveInputsFrom(nextFilter, newFilter)
//            // now output of the newFilter goes to next filter
//            activeFilters.insert(newFilter, at: nextFilterIndex)
//            let followingIndex = nextFilterIndex + 1 // now on the following filter
//
//            let  followingFilter = activeFilters[followingIndex]
//            followingFilter.setInput(image: newFilter.outputImage(), source: stackFilterName(newFilter, index: nextFilterIndex) )
//            followingFilter.setSourceFilter(sourceLocation: (source: self, at: nextFilterIndex ), attributeKey: kCIInputImageKey)
//            activeFilterIndex = followingIndex
//        }
//        if newFilter.storedFilter != nil {
//            // if nil it will be created as save time
////            storedStack?.insertIntoFilters(newFilter.storedFilter!, at: activeFilterIndex)
//            storedStack?.addToFilters(newFilter.storedFilter!)
//            // the case of firstFilterIsActive() has set activeFilterIndex to zero
//        }
//
//          updateFilterList()
//
//    }
//
//    func addFilterBefore(newFilter: PGLSourceFilter) {
//        // assumes activeFilterIndex is set to the endingPoint
//        let oldActiveFilter = activeFilters[activeFilterIndex ]
//        if firstFilterIsActive() {
//            // remove inputs of newFilter
//            // set outputs to oldFirstFilter
//            let otherKeys = newFilter.imageInputAttributeKeys
//            for anImageKey in otherKeys{
//                newFilter.setImageValue(newValue: CIImage.empty(), keyName: anImageKey)
//                newFilter.setInputImageParmState(newState: ImageParm.missingInput)
//                }
//
//            oldActiveFilter.setInput(image: newFilter.outputImage(), source: stackFilterName(newFilter, index: 0) )
//            oldActiveFilter.setInputImageParmState(newState: ImageParm.inputPriorFilter)
//            oldActiveFilter.setSourceFilter(sourceLocation: (source: self, at: 0), attributeKey: kCIInputImageKey)
//            activeFilters.insert(newFilter, at: 0)
//            activeFilterIndex = 0
//        } else {
//            // set input of newFilter as the  old inputs of old ActiveFilter
//            // set output of newFilter to input of old ActiveFilter
//
//
//            moveInputsFrom(oldActiveFilter, newFilter)
//                // remove newFilter from it's old position first?
//
//            activeFilters.insert(newFilter, at: activeFilterIndex )
//                       // pushes old active forward one..
//           oldActiveFilter.setInput(image: newFilter.outputImage(), source: stackFilterName(newFilter, index: activeFilterIndex) )
//            oldActiveFilter.setInputImageParmState(newState: ImageParm.inputPriorFilter)
//           oldActiveFilter.setSourceFilter(sourceLocation: (source: self, at: activeFilterIndex), attributeKey: kCIInputImageKey)
//
//
//        }
//        if newFilter.storedFilter != nil {
//            // if nil it will be created as save time
////            storedStack?.insertIntoFilters(newFilter.storedFilter!, at: activeFilterIndex)
//            storedStack?.addToFilters(newFilter.storedFilter!)
//            // the case of firstFilterIsActive() has set activeFilterIndex to zero
//        }
//          updateFilterList()
//
//    }

   

    


    
    func append(_ newFilter: PGLSourceFilter) {
        // private - assumes inputs are set
        activeFilters.append(newFilter)
        activeFilterIndex = activeFilters.count - 1 // zero based index
        updateFilterList()
    }

    func appendFilter(_ newFilter: PGLSourceFilter) {
        // called from the UI - connect the output to input
//        NSLog("PGLFilterStack -> appendFilter = \(newFilter.filterName)")
        if !activeFilters.isEmpty {
            let currentFilter = activeFilters[activeFilterIndex]
            let priorOutput = imageUpdate(nil, true) // inputImage: showCurrentFilterImage:

            newFilter.setInput(image: priorOutput ,source: stackFilterName(currentFilter, index: activeFilterIndex))

            if !currentFilter.imageInputIsEmpty() {
                // issue - when current filter input is fixed then newFilter state should change too
                // see check in #imageUpdate empty to inputPriorFilter state
                newFilter.setInputImageParmState(newState: ImageParm.inputPriorFilter) }

        } else {
            // first filter in the stack
            if let inputImageAttribute = newFilter.getInputImageAttribute() {
                if inputImageAttribute.inputStack == nil {
                    if inputImageAttribute.imageInputIsEmpty() {
                        newFilter.setInputImageParmState(newState: ImageParm.missingInput)
                    }
                } else {
                    newFilter.setInputImageParmState(newState: ImageParm.inputChildStack)
                }
            }


        }
        newFilter.setSourceFilter(sourceLocation: (source: self, at: activeFilterIndex), attributeKey: kCIInputImageKey)
        append(newFilter)
     

    }
   
    
    fileprivate func moveInputsFrom(_ oldFilter: PGLSourceFilter, _ newFilter: PGLSourceFilter) {
        // strictly this should only be used when replacing a filter
        // keep as many inputs as possible.
       let otherKeys = newFilter.imageInputAttributeKeys
        
        for anImageKey in otherKeys{
            if oldFilter.imageInputAttributeKeys.contains(anImageKey) {
                guard let inputAttribute = oldFilter.attribute(nameKey: anImageKey)
                else { return }
                guard let newAttribute = newFilter.attribute(nameKey: anImageKey)
                else { return }

                if let oldValue = oldFilter.localFilter.value(forKey: anImageKey) as? CIImage
                    {newFilter.setImageValue(newValue: oldValue, keyName: anImageKey)

                newAttribute.inputCollection = inputAttribute.inputCollection
                newAttribute.setTargetAttributeOfUserAssetCollection()
                newAttribute.setImageParmState(newState: inputAttribute.inputParmType() )
                newAttribute.inputStack = inputAttribute.inputStack
                newAttribute.inputSource = inputAttribute.inputSource
                newAttribute.inputSourceDescription = inputAttribute.inputSourceDescription
                // this setting of inputCollection
                // does NOT setup clones
                // therefore it does not call
                // setImageCollectionInput
                }
            }
            
         else
                 { newFilter.setImageValue(newValue: CIImage.empty(), keyName: anImageKey)
                    let newAttribute = newFilter.attribute(nameKey: anImageKey)
                    newAttribute?.setImageParmState(newState: ImageParm.missingInput)
                    }
            }
        }
    func performFilterPick(selectedFilter: PGLSourceFilter) {
        switch stackMode {
            case .add :
                appendFilter(selectedFilter)
                stackMode = .replace // for continued changes
            case .replace:
                replace(updatedFilter: selectedFilter)

        }
    }

    func replace(updatedFilter: PGLSourceFilter) {

        updatedFilter.setCIContext(detectorContext: imageCIContext)
        replaceFilter(at: activeFilterIndex, newFilter: updatedFilter)
    }
    
    func replaceFilter(at: Int, newFilter: PGLSourceFilter) {
        if isEmptyStack(){
            append(newFilter)
        }
        if at < activeFilters.count  {
            // in range
            let oldFilter = activeFilters[at]
            moveInputsFrom(oldFilter, newFilter)

            activeFilters[at] = newFilter

            // a delete and add of storedFilters
            if let oldStoredFilter = oldFilter.storedFilter {
                storedStack?.removeFromFilters(oldStoredFilter)}
            if newFilter.storedFilter != nil {
                storedStack?.addToFilters(newFilter.storedFilter!)  }
        }
        updateFilterList()
    }

    
    func removeLastFilter() -> PGLSourceFilter? {
        var removedFilter: PGLSourceFilter?
        if !activeFilters.isEmpty {
            if let myLastFilter = activeFilters.last {
               if let storedFilter = myLastFilter.storedFilter  // maybe nil if not saved to core data
                    { storedStack?.removeFromFilters( storedFilter) }
            removedFilter = activeFilters.removeLast()
            activeFilterIndex = activeFilters.count - 1 // zero based index
            }
        }
        return removedFilter //may be nil
    }

     func removeDefaultFilter() -> PGLSourceFilter? {
            var removedFilter: PGLSourceFilter?
            if !activeFilters.isEmpty {
                    removedFilter = activeFilters.removeLast()
                    activeFilterIndex = activeFilters.count - 1 // zero based index
            }
                return removedFilter //may be nil

        }

    func removeAllFilters() {
        if storedStack != nil {
            // then the filters must have storedFilter objects too
//            let filterRange = NSRange(location: 0, length: (activeFilters.count - 1))
//            let filterIndexSet = NSIndexSet(indexesIn: filterRange )
            if let cdFiltersToRemove = (storedStack?.filters) {
                storedStack?.removeFromFilters(cdFiltersToRemove) }
        }
        activeFilters = [PGLSourceFilter]()
        activeFilterIndex = -1 // nothing
//        setStartupDefault() // need at least one filter
    }

    func isEmptyDefaultStack() -> Bool {
        // has single filter with no image inputs
        if (activeFilters.count > 1) {
            return false
        }
        return activeFilters[0].imageInputIsEmpty()
    }

    func stackHasFilter() -> Bool {
        return !activeFilters.isEmpty
    }

    fileprivate func childStackResetParent() {
        if parentAttribute != nil {
            // update the parent state too
            if let parentImageAttribute = parentAttribute as? PGLFilterAttributeImage {
                parentImageAttribute.setImageParmState(newState: ImageParm.missingInput)
                parentImageAttribute.inputStack = nil
                if let cdImage = parentImageAttribute.storedParmImage {
                    cdImage.inputStack = nil
                }
            }
        }
    }

    func removeFilter(position: Int) -> PGLSourceFilter?{
        // returns removedFilter


        switch activeFilterIndex {
            case -1  :
                // somehow empty stack is removing a filter
                removeAllFilters()
                childStackResetParent()
                return nil
            case _ where ( activeFilters.count == 1) :
                // removing only filter in the stack
                removeAllFilters()
                childStackResetParent()
                return nil
            case _ where (position >= activeFilters.count - 1) :
                // on last filter
                return removeLastFilter()
            default:
                // all other cases where stack has multiple filters, take out a mid point
                let oldFilter = activeFilters.remove(at: position)
                activeFilterIndex = position
                // now outputs of prior filter go to the new activeOne inputs
                let newFilter = activeFilters[activeFilterIndex]
                moveInputsFrom(oldFilter, newFilter)
                if oldFilter.storedFilter != nil {
                    storedStack?.removeFromFilters(oldFilter.storedFilter!)}
                return oldFilter
        }

    }

    func hasMultipleFilters()-> Bool {
        return activeFilters.count > 1
    }

    func queuePosition() -> Stack {
        if !hasMultipleFilters() {
            return Stack.begin
        }
        if (activeFilterIndex == 0) {
            return Stack.begin
        }
        if activeFilterIndex < activeFilters.count - 1 {
            return Stack.middle
        }
        if activeFilterIndex == activeFilters.count - 1 {
            return Stack.end
        }
        return Stack.end // default return
    }
    // MARK: Output


    func outputImage() -> CIImage? {
        // this does not do the chaining of output to input used by stackOutputImage
        if activeFilterIndex >= 0 {
            return activeFilters.last!.outputImage() }
        else {
            return CIImage.empty() }
    }

    func stackOutputImage(_ showCurrentFilterImage: Bool) -> CIImage {
        //assumes that inputImage has been set
        if activeFilterIndex < 0 {
            return CIImage.empty() }

        if useOldImageFeedback {
            // always false - only changes with inspectable var in the debugger
            if let startImage = activeFilters.first?.inputImage() {
                return imageUpdate(startImage, showCurrentFilterImage)
                // passing startImage will trigger a new input for any detectors..
                // but this runs every frame !
            }
            else {
                return CIImage.empty() }
        } else {
            return imageUpdate(nil, showCurrentFilterImage)  // uses current image already set in the filter
        }
    }


    func imageUpdate(_ inputImage: CIImage?, _ showCurrentFilterImage: Bool) -> CIImage {
        // send the inputImage to the activeFilters

        var thisImage = inputImage
        var filter: PGLSourceFilter
        var imagePosition: Int
//       NSLog("PGLFilterStack #imageUpdate inputImage = \(String(describing: inputImage))")

        if isEmptyStack() { return CIImage.empty() }
        if showCurrentFilterImage {
            imagePosition = activeFilterIndex
        } else {
            imagePosition = activeFilters.count - 1 // zero based array
            }

        for index in 0...imagePosition { // only show up to the current filter in the stack
//            NSLog("imageUpdate START thisImage.extent = \(thisImage?.extent)")
            if index >  activeFilters.count - 1 {
                continue // stack changed by up/down navigation so bail
            }
            filter = activeFilters[index]
            if filter.imageInputIsEmpty() {
                if thisImage == nil {
                    // don't render from filter with no input.
                    continue
                }
            }
            if thisImage != nil {
                if thisImage!.extent.isInfinite {
                    // issue CIColorDodgeBlendMode -> CIZoomBlur -> CIToneCurve
                    // -> CIColorInvert -> CIHexagonalPixellate -> CICircleSplashDistortion)
                    // clamp and crop if infinite extent
//                  NSLog("PGLFilterStack imageUpdate thisImage has input of infinite extent")

                    thisImage = thisImage!.cropForInfiniteExtent()
//                    if doPrintCropClamp {   NSLog("PGLFilterStack imageUpdate clamped and cropped to  \(String(describing: thisImage?.extent))") }
                }
                filter.setInput(image: thisImage, source: nil)
                if filter.imageInputIsEmpty() {
                    if let changedAttribute = filter.getInputImageAttribute() {
                        changedAttribute.setImageParmState(newState: ImageParm.inputPriorFilter)
                    }
                }
            }


            if let newOutputImage = clampCropForNegativeX(input: filter.outputImage()) {

                if newOutputImage.extent.isInfinite {
//                    NSLog("PGLFilterStack imageUpdate newOutputImage has input of infinite extent")
                }
                thisImage = filter.scaleOutput(ciOutput: newOutputImage, stackCropRect: cropRect)
                    // most filters do not implement scaleOutput
                    // crop in the PGLRectangleFilter scales the crop to fill the extent

            } else {
               thisImage = inputImage
                // for next loop of activeFilters
//                NSLog("PGLAppStack #outputFilterStack() no output image at \(index) from filter = \(filter.filterName)")
                }
            }

        return thisImage ?? CIImage.empty()
      
    }

    func clampCropForNegativeX(input: CIImage?) -> CIImage? {
        var returnImage: CIImage!

        guard let actualInput = input else {
            return input
        }
        if actualInput.extent.isInfinite {
            // clampCrop not needed here.. insetRect goes to zero in this case
            return input}
        
        if ( actualInput.extent.minX  < 0) {
            // has a negative value in origin x
            // negative causes frame to offset with black border to show the origin
            // from https://developer.apple.com/videos/play/wwdc2018/503
            // crop then clamp

           let offset = abs(actualInput.extent.minX )

            let insetRect = actualInput.extent.inset(by: UIEdgeInsets(top: offset, left: offset, bottom: offset, right: offset))

            let clampedImage = actualInput.clampedToExtent() // makes infinite
             returnImage = clampedImage.cropped(to: insetRect)

        } else {
             returnImage =  actualInput
        }

        if doPrintCropClamp {
            Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLFilterStack newOutputImage clamped and cropped to  \(returnImage)")

        }
        if returnImage.extent.isInfinite {
            Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLFilterStack error clampCrop() returning infinite extent \(returnImage)")

        }
        return returnImage
    }



    func basicFilterOutput() -> CIImage {
        //bypass all the input changes and chaining

        return  currentFilter().outputImage() ??
            CIImage.empty()
    }
    func updateFilterList() {}

    // MARK: flattened Filters

    func addChildFilters(_ level: Int, into: inout Array<PGLFilterIndent>) {
    // make sure to travers the appStack in the same order
    // adds/deletes of filters require the whole flatten array to regenerate.
        var indexCounter = 0
        for aFilter in activeFilters {
//            into.append(PGLFilterIndent(level, aFilter))
            into.append(PGLFilterIndent(level, aFilter, inStack: self,index: indexCounter))
            let nextLevel = level + 1
            aFilter.addChildFilters(nextLevel, into: &into)
            indexCounter += 1
        }

    }

    func stackRowCount() -> Int {
        // number of filters including the filters of child stacks
        var childRowCount = 0
        for aFilter in activeFilters {
            childRowCount += aFilter.stackRowCount()
        }
        return childRowCount
    }

    // MARK: Navigation / numbering


    func currentFilter() -> PGLSourceFilter {
         return filterAt(tabIndex: activeFilterIndex)
    }
//    func nextFilter()  -> PGLSourceFilter? {
//        // either add new if currently at last or move to next in the stack
//        stackNextFilter()  // this changes the filter by adding to the stack
//        //        filterUpdate(updatedFilter: currentFilter()!)
//        return filterAt(tabIndex: activeFilterIndex)
//    }

    func priorFilter() -> PGLSourceFilter? {
        // either move to prior in the stack or just the first if only 1

        moveActiveBack() // this changes the filter by adding to the stack
        //        filterUpdate(updatedFilter: currentFilter()!)
        return filterAt(tabIndex: activeFilterIndex)
    }


    func filterNumber() -> Int {
        return  activeFilterIndex + 1
    }

    func currentFilterPosition() -> PGLFilterCategoryIndex {
        let theCurrentFilter = filterAt(tabIndex: activeFilterIndex)
        return theCurrentFilter.uiPosition
    }

    func filterName() -> String {
        if activeFilterIndex < 0 { return ""}
        if activeFilters.count == 0 {return "" }
        let theCurrentFilter = filterAt(tabIndex: activeFilterIndex)
        return theCurrentFilter.localizedName()
    }

    func filterNumLabel(maxLen: Int?) -> String {
        // removed category name logic 2021-04-10
        let returnString = String( filterName())

        if let localMax = maxLen {
            return String(returnString.prefix(localMax) ) }
        else { return returnString }


    }

    func nextStackName() -> String {
        // this stack name + filterNumberLabel of the current filter
        return "@->" + stackName + " filter: " + filterNumLabel(maxLen: 20)
    }



   
// MARK: Save Image

    func writeTestCDStacks(stackProvider: PGLStackProvider){
        // TEST method for saving... not called from the UI
        // called from saveStackImage
           // store starting from the top level
           // each stack will write in turn as it is referenced
           // do not need to iterate the collection
        // called by saveHEIFToPhotols
        let moContext = stackProvider.persistentContainer.viewContext
        // NOT background execution in the testing methods

       _ = self.writeCDStack(moContext: moContext)

       if moContext.hasChanges {
       do { try moContext.save()
        Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLAppStack #writeCDStacks save called")
           } catch {
            Logger(subsystem: LogSubsystem, category: LogCategory).error("writeCDStacks error alert: \(error.localizedDescription)")
            DispatchQueue.main.async {
                // put back on the main UI loop for the user alert
                let alert = UIAlertController(title: "Data Store Error", message: "PGLFilterStack writeCDStacks() \(error.localizedDescription). Try again using the 'Save As' choice", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in

                }))
                Logger(subsystem: LogSubsystem, category: LogCategory).notice("writeCDStacks error calling alert on open viewController ")
                let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
                myAppDelegate.displayUser(alert: alert)

            }
           }
               }

       }



    func saveTestStackImage(stackProvider: PGLStackProvider)  {
        // TEST method for saving... not called from the UI

        DoNotDrawWhileSave = true
           _ = self.saveTestToPhotosLibrary(stack: self, stackProvider: stackProvider)
        do { DoNotDrawWhileSave = false } // executes at the end of this function

//        }
    }

    func saveTestToPhotosLibrary( stack: PGLFilterStack, stackProvider: PGLStackProvider )   -> Bool {
                      // check if the album exists..) {
               // save the output of this stack to the photos library
                               // Create a new album with the entered title.

               var assetCollection: PHAssetCollection?


              if let existingAlbumId = stack.exportAlbumIdentifier {
                   let fetchResult  = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [existingAlbumId], options: nil)
                   assetCollection = fetchResult.firstObject

              } else {
                   // check for existing albumName
               if let aAlbumExportName = stack.exportAlbumName {
                   // find it or or create it.
                   // leave assetCollection as nil to create

                 // fatalError( "PHAssetCollection needs to search for a matching album title #saveToPhotosLibrary")
                   // how to do this???
                  let albums = getAlbums()
                    let matching = filterAlbums(source: albums, titleString: aAlbumExportName)
                   if matching.count > 0 {
                       assetCollection = matching.last!.assetCollection
                   }


                   }
               }

               return self.saveTestHEIFToPhotosLibrary(exportCollection: assetCollection, stack: stack, dataProvider: stackProvider)


    }

    func saveTestHEIFToPhotosLibrary(exportCollection: PHAssetCollection?, stack: PGLFilterStack, dataProvider: PGLStackProvider ) -> Bool {
//        if let heifImageData = PGLOffScreenRender().getOffScreenHEIF(filterStack: stack) {
        if self.exportAlbumName == nil {
            // don't export to photo lib if no album name
            self.writeTestCDStacks(stackProvider: dataProvider)
            return true
        }
        guard let uiImageOutput = PGLOffScreenRender().captureUIImage(filterStack: stack)
        else {
            return false }

//        PHPhotoLibrary.shared().performChanges({
          if let savedOk =  try? PHPhotoLibrary.shared().performChangesAndWait({

           let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: uiImageOutput)
//           heif from  creationRequest.addResource(with: .fullSizePhoto, data: heifImageData, options: nil)

            if exportCollection == nil {
                // new collection
                let assetCollectionRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: stack.exportAlbumName ?? "exportAlbum")

                assetCollectionRequest.addAssets([creationRequest.placeholderForCreatedAsset!] as NSArray)
                stack.exportAlbumIdentifier = assetCollectionRequest.placeholderForCreatedAssetCollection.localIdentifier

            } else {
                // asset collection exists
                let addAssetRequest = PHAssetCollectionChangeRequest(for: exportCollection!)
                addAssetRequest?.addAssets([creationRequest.placeholderForCreatedAsset!] as NSArray)
            }

        })
          {  // savedOk = true
            self.writeTestCDStacks(stackProvider: dataProvider)
            return true }
        else { return false }

}



    // MARK: photos Output
      func filterAlbums(source: [PGLUUIDAssetCollection], titleString: String?) -> [PGLUUIDAssetCollection] {
             if titleString == nil { return source }
             else { return source.filter { $0.contains(titleString)} }
         }

      func getAlbums() -> [PGLUUIDAssetCollection] {
          // make this generic with types parm?
          var answer = [PGLUUIDAssetCollection]()
          let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular , options: nil)
          for index in 0 ..< (albums.count ) {
                  answer.append( PGLUUIDAssetCollection( albums.object(at: index))!)

          }
//          NSLog("PGLImageCollectionMasterController #getAlbums count = \(answer.count)")
          return answer
      }

}

