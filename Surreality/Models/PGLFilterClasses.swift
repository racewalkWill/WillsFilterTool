//
//  PGLFilterClasses.swift
//  PictureGlance
//
//  Created by Will on 3/9/17.
//  Copyright © 2017 Will Loew-Blosser. All rights reserved.
//  Modifies from Apple CIFunHouse sample app file FilterStack.h
//

import Foundation
import CoreImage
import simd
import UIKit



protocol PGLAnimation {
    func addStepTime()
}



class PGLSourceFilter :  PGLAnimation  {
    // helper object for CIFilter  holds the filter and dispatches
    // PGLSourceFilter holds PGLFilterAtrributes.. make a subclass of  PGLSourceFilter if filter specific logic needed across multiple attributes
    // i.e. if constraints exist between attributes the PGLSourceFilter implements the filter as a subclass


//    let AssociationKey = "storedImageInputAttributeKeys"
    // 10/22/17 removing the cache of attributes for now .. check performance

    // Subclassing NOTE: if subclass is added similar to the PGLCropFilter then the
    // instance creation in the PGLFilterDescriptor init method needs another case..
        //    if thisName == PGLCropFilter.pglNameForFilter()?.filterName {
        //    pglSourceFilterClass = PGLCropFilter.self
        //      

    class func displayName() -> String? {
        return nil // subclasses override
        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
    }

    class func classStringName() -> String {
        return String(describing: self)
    }
    var filterName: String! {
        didSet {
            NSLog("PGLSourceFilter filterName set to String(describing:filterName)")
        }
    }
    var descriptorDisplayName: String? // not the same as the ciFilter name


    var localFilter: CIFilter 
    var attributes = [PGLFilterAttribute]() // may have subclasses
    var filterCategories = [String]()
    var uiPosition: PGLFilterCategoryIndex
    var hasImageInput = false
    var oldImageInput: CIImage?
    var storedFilter: CDStoredFilter? // managedObject - write/read to Core Data


    // animation vars
    var hasAnimation = false
    var animationAttributes = [PGLFilterAttribute]()
    var stepTime = 0.0 {
        // range -1.0 to 1.0
        didSet {
//            NSLog("PGLSourceFilter stepTime now = \(stepTime)")
        }
    }
    let defaultDt = 0.005
    var dt = 0.005{
        didSet{
            wrapper?.dt = dt
            // wrapper if active needs the rate of change dt
        }
    // rate of change for animation & increment timers
    }
    var detectors = [PGLDetection]()
    lazy var thumbNail = getThumbnail() // only set when referenced need to reset on changes..
    var wrapper: PGLDissolveWrapperFilter?
private  var userDescription: String?

@IBInspectable var debugOutputImage = false


    //MARK: subclass creation
   // add a dict pair into PGLFilterDescriptor for subclasses
    // PGLFilterDescriptor.pglFilterClassDict = ["CICrop": PGLCropFilter.self, "CICropDown": PGLCropDownFilter.self ]
    func classStringName() -> String {
        // answer the displayname of the class for use in matching
        // to the correct PGLSourceFilter class in the core data read methods.
        return String(describing: (type(of:self).self))
    }

    //MARK: instance inits
required init?(filter: String, position: PGLFilterCategoryIndex) {
        if let thisFilter = CIFilter(name: filter) {
            uiPosition = position
//            thisFilter.setDefaults()  // in iOS this is set automatically - macOS needs explicit setDefaults()
            filterCategories = thisFilter.attributes[kCIAttributeFilterCategories] as! [String]

            self.localFilter = thisFilter
//             NSLog("PGLSourceFilter #init localFilter = \(localFilter)")
            // some attributes... CIAbstractFilter could be filtered out here ie. the feature select..
            for anAttributeKey in thisFilter.inputKeys {
                let inputParmDict = (thisFilter.attributes[anAttributeKey]) as! [String : Any]

                let parmAttributeClass = PGLFilterAttribute.parmClass(parmDict: inputParmDict)
                if let thisParmAttribute = parmAttributeClass.init(pglFilter: self, attributeDict: inputParmDict, inputKey: anAttributeKey  )
                    {
                        for valueAttribute in thisParmAttribute.valueInterface() {
                            // some parmAttributes have multitple value settings (AffineTransform etc)
                            // most just answer themselves for the value UI (slider, position...)
                            attributes.append( valueAttribute )
                        }
                }

                hasImageInput =  attributes.contains { (attribute: PGLFilterAttribute ) -> Bool in
                    attribute.isImageInput()
                }
//            if !hasImageInput  {
//                if !attributes.isEmpty {
//                    hasImageInput = (attributes.last?.isImageInput())! }
//                }
                //   see also the imageInputCount computed property
            }
//            filterName = thisFilter.name  // directly set a var so the debuggers shows the name - get var does not show in the debugger
            // 6/2/19  thisFilter.name had the value  key : "CIAttributeFilterName"  value : Glance.PGLImageCIFilter
            // could not see why the ImageCIFilter was registered with the app.class name as the filter name..
            // no other filters including the other subclasses of CIFilterAbstract seemed to do this..
            // weird...

            filterName = filter // string name in the method call

        } else
            { return nil }
    }

    convenience init?(filter: String) {
       self.init(filter: filter, position: PGLFilterCategoryIndex()) // default index with zeros, empty values

    }



    func resetAttributesToLocalFilter() {
        // if the local filter (a CIFilter) is changed then the
        // attributes all need it too.. this occurs in the CoreData read
        for anAttribute in attributes {
            anAttribute.myFilter = self.localFilter
        }
    }

    func setCIContext(detectorContext: CIContext?) {
        // super class does nothing
        // subclasses using a CIDetector will use this

    }

    func isTransitionFilter() -> Bool {
        // answers true if filterCategories contains value "CICategoryTransition"
        // only transition filters should have multiple images in a parm imageList
         return filterCategories.contains("CICategoryTransition")

    }

 

    // MARK: input/output
    fileprivate func setDetectorsInput(_ image: CIImage?, _ source: String?) {
        // make all input image go to this method
        for aDetector in detectors {
            aDetector.setInput(image: image, source: source)
            // detector checks for features on setInput
            if let myLocalCIAbstractFilter = localFilter as? PGLFilterCIAbstract {
                // other CIFilters do not have the features var
                myLocalCIAbstractFilter.features = aDetector.features
            }
        }
    }

    func setInput(image: CIImage?, source: String?) {

        if hasImageInput {
            if oldImageInput !== image  && ( image != nil) { // same condition used in subclass PGLDetectorFilter.setInput
                // ignore changes in the image input for successive frames.
                oldImageInput = image
// uncomment this logging to see the frame by frame .. also lists the kernel in the filter... for CIDepthOfField it's more than you would think.
                if debugOutputImage { NSLog("PGLSourceFilter setInput(image: didSet = \(String(describing: image))") }
//                localFilter.setValue(image, forKey: kCIInputImageKey)

                setImageValue(newValue: image!, keyName: kCIInputImageKey)

                if source != nil {setSource(description: source!, attributeKey: kCIInputImageKey)}
            }
            // let the addStepTime do this
           setDetectorsInput(image, source) // same condition used in subclass PGLDetectorFilter.setInput
        }
    }





    var imageInputCount: Int {
        // computed property
        return (imageInputAttributeKeys.count)
    }
    
    var imageInputAttributeKeys: [String] {
        //computed property
        var imageKeyFound = false
        var addingArray = [String]()
        for key in localFilter.inputKeys {
            imageKeyFound = false // reset for each key
            if let attrDict = localFilter.attributes[key]  {
                let thisDict = attrDict as! [String : Any]
                if let attributeType = thisDict[kCIAttributeType] as? String {
                    if attributeType == kCIAttributeTypeImage {
                        addingArray.append(key)
                        imageKeyFound = true
                        }
                }
                else { // no attributeType entry found
                     if let attributeClass = thisDict[kCIAttributeClass] as? String {
                            if !imageKeyFound && (attributeClass == "CIImage") {
                                // don't add twice if both attributeClass and attributeType are listed
                                addingArray.append(key)
                                imageKeyFound = true
                            }
                        }

                }

                if !imageKeyFound {
                    // case for another attribute type ..
                    // such as inputGradientImage in CIColorMap
                    // which has attibuteClass of CIImage
                    if let attributeClass = thisDict[kCIAttributeClass] as? String {
                           if (attributeClass == "CIImage") {
                               // don't add twice if both attributeClass and attributeType are listed
                               addingArray.append(key)
                               imageKeyFound = true
                           }
                       }

                }
            } // attributes of this key
        }  // end key for loop
        return  addingArray
    }


    var imageInputCache: [String :CIImage?] = [:]

     func otherImageInputKeys() -> [String] {
            // answers other image inputs
            // does not include the common kCIInputBackgroundImageKey, kCIInputImageKey
            // not currently used.. but seems useful at some point.
            var otherKeys = imageInputAttributeKeys
            otherKeys.removeAll(where: {$0 == kCIInputBackgroundImageKey})
            otherKeys.removeAll(where: {$0 == kCIInputImageKey})
            return otherKeys
        }

    func imageInputIsEmpty() -> Bool {
        // used for images filter to remove if no input is set
        for imageAttributeKey in imageInputAttributeKeys {
            if let inputAttribute = attribute(nameKey: imageAttributeKey )
            {
                if  inputAttribute.inputParmType() == ImageParm.missingInput
                        { return true }
            }
        }
        return false // default return - all inputs are populated or none are image inputs
    }

    func setInputImageParmState(newState: ImageParm) {
        if let inputImageAttribute = getInputImageAttribute() {
            inputImageAttribute.setImageParmState(newState: newState)
        }
    }

    func getInputImageAttribute()-> PGLFilterAttributeImage? {
        if let inputImageAttribute = attribute(nameKey: kCIInputImageKey ) {
            return inputImageAttribute as? PGLFilterAttributeImage
        }
        return nil
    }

    func localizedName() -> String {
      return  CIFilter.localizedName(forFilterName: localFilter.name) ?? "unNamed"
    }

    func outputImage() -> CIImage? {
        // if any inputs are from another filter then they should be updated first

        addStepTime()  // if animation then move time forward
        // increments this filter detectors 
        if wrapper != nil {

//            addStepTime()  // if animation then move time forward
            return wrapper!.outputImageBasic()}

        else { return outputImageBasic()}
            // notice that addStepTime is called  inside the outputImageBasic

    }

    func firstDetector() -> PGLDetection? {
        return detectors.first
    }
    func outputImageBasic() -> CIImage? {
        // assumes addStepTime() is called before this

        // wrapper may call this to produce wrapper effects on the basicImage
        addStepTime()  // if animation then move time forward
        for anAttribute in attributes {
                    anAttribute.updateFromInputStack()
                }
        let thisOutput = localFilter.outputImage
        //        thisOutput?.cropped(to: thisOutput!.extent)
                if debugOutputImage { NSLog("PGLSourceFilter outputImage =  \(String(describing: thisOutput))")  }
        return thisOutput
    }

    func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {
        // empty implementation answers the input
        // subclassses such as PGLRectangleFilter which crops implement
        return ciOutput
    }
     func setDefaults() {
        // in iOS this is set automatically - macOS needs explicit setDefaults()
        // test cases are callers so comment out to
        // get tests to run same as runtime

        // localFilter.setDefaults()
    }




    
    func isBackgroundImageInput() -> Bool {
        return attributes.contains { (attribute: PGLFilterAttribute ) -> Bool in
            attribute.isBackgroundImageInput()
        }
    }

    // MARK: thumbnails
    func getThumbnail(dimension: CGFloat = 200.0 ) -> UIImage{

            if  let ciOutput = outputImage() {

                // output image in thumbnail size
                let magicNum: CGFloat  = dimension  // 44.0 numerator for ratio to max dimension of the image

                let uiOutput = UIImage(ciImage: ciOutput )

                let outputSize = uiOutput.size
                //        let outputFrame = outputImage.extent
                var ratio: CGFloat = 0
                ratio = magicNum / max(outputSize.width, outputSize.height)

                let smallSize = CGSize(width: (ratio * outputSize.width), height: (ratio * outputSize.height))
                let smallRect = CGRect(origin: CGPoint.zero, size: smallSize)

                UIGraphicsBeginImageContext(smallSize)
                uiOutput.draw(in: smallRect)
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return thumbnail ?? UIImage()
            }

        return UIImage()
    }

    func fullFilterName() -> String {
        // both localized name in the interface and the ciFilter name
        // use in NSLog statements
        return "\(String(describing:self.localizedName())) \(String(describing: self.filterName)))"
    }

    func filterUserDescription() -> String? {
        if userDescription == nil {
            if let myuserDescriptor = PGLFilterCategory.getFilterDescriptor(aFilterName: self.filterName, cdFilterClass: classStringName()) {
                    userDescription = myuserDescriptor.userDescription
            }
        }
        return userDescription
    }
    
    // MARK: value double dispatch

     func postImageChange() {
        let outputImageUpdate = Notification(name:PGLOutputImageChange)
        NotificationCenter.default.post(outputImageUpdate)
    }
    
    func setImageValue(newValue: CIImage, keyName: String) {
//        NSLog("PGLFilterClasses #setImageValue key = \(keyName)")
//        newValue.clampedToExtent()
        // test changing all inputs to the same extent
        
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }

    func removeImageValue(keyName: String) {
        localFilter.setValue(nil, forKey: keyName)
    }

    func setBackgroundInput(image: CIImage?) {
        if isBackgroundImageInput() {
            localFilter.setValue( image, forKey: kCIInputBackgroundImageKey)
            postImageChange()
        }
    }


    func setNumberValue(newValue: NSNumber, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setVectorValue(newValue: CIVector, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setColorValue(newValue: CIColor, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setDataValue(newValue: NSData, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setNSValue(newValue: NSValue, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setObjectValue(newValue: NSObject, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setStringValue(newValue: NSString, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }

    func setAttributeStringValue(newValue: NSAttributedString, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }

    

    
    
    func valueFor( keyName: String) -> Any? {
        return localFilter.value( forKey: keyName)
    }

    func inputImage() -> CIImage?  {
        if hasImageInput {
            return valueFor(keyName: kCIInputImageKey) as? CIImage
        }
        else {
            return CIImage.empty()}
    }

// MARK: flattened Filters
    func stackRowCount() -> Int {
        // answer 1 plus the count of filters in the input parm stacks
        // usually 1
        var childRowCount = 0
        for aParm in attributes {
            childRowCount += aParm.stackRowCount()
        }
        return 1 + childRowCount  // answer 1 row for the filter
    }

    func addChildFilters(_ level: Int, into: inout Array<PGLFilterIndent>) {
        // called for flattened filters
        for aParm in attributes {
            if aParm.hasFilterStackInput() {
                aParm.addChildFilters(level, into: &into )
            }
        }

    }

     // MARK: input source
    func attribute(nameKey: String) -> PGLFilterAttribute? {
        if let sourceIndex = attributes.firstIndex(where: {$0.attributeName == nameKey})
        { return attributes[sourceIndex]}
        else { return nil }
    }

    func setSourceFilter(sourceLocation: (source: PGLFilterStack, at: Int),attributeKey: String) {
        // checking memory circular ref between aSourceFilter and inputSource vars
        // 2020-10-20 comment out below
//        if let sourceAttribute = attribute(nameKey: attributeKey)
//        {  sourceAttribute.inputSource = sourceLocation
//            if let imageAttribute = sourceAttribute as? PGLFilterAttributeImage {
//                if ( sourceLocation.at > 0 ) {
//                // first zero position filter can not have input from a previous filter
//                imageAttribute.hasFilterInput = true  // flag for parm description
//
//                }
//            }
//        }
    }

    func resetDrawableSize() {
        guard let myImageParms = imageParms()
            else {return }
        for anImageParm in myImageParms {
            anImageParm.resetDrawableSize()
        }
    }

    func getSourceFilterLocation(attributeKey: String) -> (source: PGLFilterStack, at: Int)? {
        if let sourceAttribute = attribute(nameKey: attributeKey)
            { return sourceAttribute.inputSource  }
        else {return nil }
    }

    func getSourceFilter(attributeKey: String) -> PGLSourceFilter? {
        if let sourceLocator = getSourceFilterLocation(attributeKey: attributeKey) {
            let theIndex = sourceLocator.at
            return (sourceLocator.source).filterAt(tabIndex: theIndex)

        }
        else { return nil}

    }
    func sourceDescription(attributeKey:String) -> String  {
        if attribute(nameKey: attributeKey) != nil
            { return self.localizedName() + "-" + filterName }  // + "-" + sourceAttribute.inputSourceDescription 
        else { return "blank" }

    }

    func setSource(description: String, attributeKey:String) {
        if let sourceAttribute = attribute(nameKey: attributeKey)
            { sourceAttribute.inputSourceDescription = description }
    }

    func backgroundImage() -> CIImage? {
        return valueFor(keyName: kCIInputBackgroundImageKey) as? CIImage
        }

// MARK: Filter Animation frame changes
    func stopAnimation(attributeTarget: PGLFilterAttribute) {
        
        if attributeTarget.attributeValueDelta != nil {
                   // stop the animation

            attributeTarget.attributeValueDelta = nil
                // turns off animation at the attribute

                // MARK: Fix set the filter level dt here
               animationAttributes.removeAll { (anAttribute: PGLFilterAttribute) -> Bool in
                   anAttribute.attributeName == attributeTarget.attributeName
                   }
                hasAnimation = ( animationAttributes.count > 0 )
               }
    }

    func startAnimation(attributeTarget: PGLFilterAttribute) {
//    if attributeTarget.attributeValueDelta == nil {
        // start the animation
        hasAnimation = true

//        attributeTarget.varyTotalFrames = 600 // start animation logic at 10 sec * 60 fps
        animationAttributes.append(attributeTarget)

//        attributeTarget.attributeValueDelta = Float(dt ) // default rate of change from the filter
//        }
    }



    func removeWrapperFilter() {

        if let faceDetector = detectors.first {
            faceDetector.releaseTargetAttributes()
        }
            wrapper?.releaseWrapper()
            wrapper = nil
       hasAnimation = false
        
    }

    func setWrapper(outputFilter: PGLDissolveWrapperFilter, detector: PGLDetection) {

//        output.setImageAnimation()
        wrapper = outputFilter
        detector.setOutputAttributes(wrapperFilter: outputFilter)
        detectors.append(detector)
        let startImage = inputImage()
        setDetectorsInput(startImage, nil)
        outputFilter.updateInputs(detector: detector)
        // gets 2 images for the dissolve: input and target
        outputFilter.detectorFilter = detector
            // output will trigger to detector when
            // an image should change
           // change at dissolve rate increment when offscreen
    }

    func animate(attributeTarget: PGLFilterAttribute) {
        // put the attribute into receiver array for addStepTime and increment messages
//         fatalError("animate(attributeTarget: is replaced by stop start methods")
        if hasAnimation {
            stopAnimation(attributeTarget: attributeTarget)
        }
        else {
            startAnimation(attributeTarget: attributeTarget)
        }
//        if attributeTarget.animationTime != nil {
//            // stop the animation
//
//            attributeTarget.animationTime = nil
//            attributeTarget.setTimerDt(rate: defaultDt)
//            animationAttributes.removeAll { (anAttribute: PGLFilterAttribute) -> Bool in
//                anAttribute.attributeName == attributeTarget.attributeName
//            }
//             hasAnimation = ( animationAttributes.count > 0 )
//        }
//        else { // start the animation
//            hasAnimation = true
//
//            attributeTarget.animationTime = 0.0 // start animation logic
//            animationAttributes.append(attributeTarget)
//
//            attributeTarget.attributeDt = defaultDt // default rate of change from the filter
//
//        }
    }

    func attribute(removeAnimationTarget: PGLFilterAttribute) {
        // remove the attribute from the receiver array for addStepTime and increment messages
        // a duplicate of the remove logic in animateTarget..
        // delete this method??
        removeAnimationTarget.attributeValueDelta = nil // stop animation logic
        animationAttributes.removeAll { (anAttribute: PGLFilterAttribute) -> Bool in
            anAttribute.attributeName == removeAnimationTarget.attributeName
        }
    }

    func addStepTime() {
        // called on every frame
        // this does not send the increment message to the inputImage parm.
        // use PGLTransitionFilter for imageList image increment .
        
//        wrapper?.addStepTime() // usually nil so not sent

        if hasAnimation {
            if (stepTime > 1.0) || (stepTime < -1.0) {
                dt = dt * -1
                    // maybe just set to -1.0 or 1.0.. multiply may be slightly over the 1 value.
                
                for aDetector in detectors {
                    aDetector.increment()  // advances to the next feature
                }
            }
            // go back and forth between -1.0 and 1.0
            // toggle dt either neg or positive
            stepTime += dt
                /*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
                 *  @discussion You can use a scalar value for edge0 and edge1 if you want
                 *  to clamp all lanes at the same points.
                             let inputTime = simd_smoothstep(-1.0, 1, stepTime)
                 */
            let inputTime = stepTime
            for aDetector in detectors {
                aDetector.setInputTime(time: Double(inputTime)) 
            }
            for parm in animationAttributes {
                parm.addStepTime()

        }
    }
    }

    func setTimerDt(lengthSeconds: Float) {
        // empty implementation
        // see PGLTransitionFilter implementation
        // attributes have independent timer cycle for the Vary
        // this is for timerLoops at the filter level (ie. TransitionFilters)

    }

    func updateChange(_ frameDelta: PGLFilterChange) {
        // if any attributes in this filter match the key in the frameDelta
        // then alter the value by the delta in the change record
        // min/max issues?
    }

    func setImageListClone(cycleStack: PGLImageList, sourceKey: String) {
        // empty implementation
        // PGLTransitionFilter subclass will  clone cycleStack to other parms

    }

}


//extension PGLSourceFilter : Equatable {
//    static func == (lhs: PGLSourceFilter, rhs: PGLSourceFilter) {
//        filter
//
//    }
//}

class PGLDetector: PGLDetection {
    // uses older CIDetectors.. see also the new PGLVisionDetector and the Vision framework

    // REDO below comment for new design
    // subclass of PGLSourceFilter to dispatch to a detector
    // +++++++++++++++
    // PGLDetectorFilter and FaceFilter are connected in PGLFilterDescriptor class var pglFilterClassDict
    //  with the key value pair of  "FaceFilter": PGLDetectorFilter.self
    //  PGLFaceFilter: CIFilter and has the registered name of "FaceFilter"
    // this design captures the image features when the input is set and holds the detector
    // both are expensive operations
    
    var viewCIContext: CIContext?
    var  detector: CIDetector?
    var  features = [PGLFaceBounds]() {
        didSet {  displayFeatures = features.indices }
        }
    var  displayFeatures: CountableRange<Int>?
    var localFilter: CIFilter?  // filter to produce outputs on the detected features  rename?
    var inputImage: CIImage?
    var oldInputImage: CIImage?
    var filterAttribute: PGLFilterAttribute?
    var targetInputAttribute: PGLFilterAttributeImage?
    var targetInputTargetAttribute: PGLFilterAttributeImage?

    // animation
    var inputTime = 0.0 // ranges -1.0 to +1.0 for animation
        // Double

    var currentFeatureIndex = 0
    // detector and features vars also used in CIFilterAbstract for the Bump and Face CI filter subclasses

    enum Direction: Int {
        case forward = 1
        case back = -1
    }
    // init
    required init(ciFilter: CIFilter?) {
        localFilter = ciFilter
        // requires setCIContext to function but needs to be sent later
    }

    func setCIContext(detectorContext: CIContext?) {
        // superclass has empty implementation

        if detectorContext != nil {
            detector = CIDetector.init(ofType: CIDetectorTypeFace, context: detectorContext!, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh, CIDetectorTracking:true])
            viewCIContext = detectorContext!
        }
    }

    func releaseContext() {
        // release everything 
        detector = nil
        features = [PGLFaceBounds]()
        localFilter = nil
        inputImage = nil
        oldInputImage = nil

        viewCIContext?.clearCaches()
        viewCIContext = nil
    }

    func releaseTargetAttributes() {
        targetInputTargetAttribute = nil
        targetInputAttribute = nil
    }

    // MARK: animation

    func setInputTime(time: Double) {
        inputTime = time
    }

    func increment() {
          // 12/2/19 should have a dissolve on incremnent for smooth change to next feature
          // moves upward to features.count. then returns to start at zero
        nextFeature(to: Direction.forward)

      }
    
    func nextFeature(to: Direction) {
        // 12/2/19 should have a dissolve on incremnent for smooth change to next feature
        // moves upward to features.count. then returns to start at zero
        NSLog("PGLDetector nextFeature start currentFeatureIndex = \(currentFeatureIndex) features.count = \(features.count)")
        currentFeatureIndex += to.rawValue
        if (currentFeatureIndex >= features.count) || (currentFeatureIndex < 0) {
            currentFeatureIndex = 0
        }
        NSLog("PGLDetector nextFeature end currentFeatureIndex = \(currentFeatureIndex) features.count = \(features.count)")
//        setFeaturePoint()
    }

    // set features
    func setFeaturePoint(){
        // put the center of the first feature into the point value of the attribute
         NSLog("PGLDetector setFeaturePoint currentFeatureIndex = \(currentFeatureIndex) features.count = \(features.count)")
        if features.isEmpty {return }
        if currentFeatureIndex >= features.count {return}
        let mainFeature = features[currentFeatureIndex]
        let mainBox = mainFeature.boundingBox() ?? CGRect.zero
        let centerX = mainBox.midX
        let centerY = mainBox.midY
        let pointVector = CIVector(x:centerX, y: centerY)
        filterAttribute?.set( pointVector)
        NSLog("PGLDetector setFeaturePoint = \(pointVector)")

    }

     func setInput(image: CIImage?, source: String?) {
//               NSLog("PGLDetector setInput")
        // called every imageUpdate by the PGLFilterStack->filter.setInput->detectors#setInput
            var resetNewFaces = false
            if let anInputImage = image {
                inputImage = anInputImage
                if oldInputImage === inputImage {
//                    NSLog("PGLDetector no action same image setInput")
                    return } // don't process twice


//                localFilter?.setDefaults()
//                localFilter?.setValue(inputImage, forKey: kCIInputImageKey)
                oldInputImage = inputImage
                
                let newCIFeatures = detector?.features(in: anInputImage) ?? [CIFaceFeature]()
                var newFaceBoxes = [PGLFaceBounds]()
                for aCIFeature in newCIFeatures {
                    newFaceBoxes.append(PGLFaceBounds(onVNFace: nil, onCIFace: aCIFeature as? CIFaceFeature))
                }
                features = [PGLFaceBounds]() // reset
                for aFeature in newFaceBoxes {

                     features.append(aFeature)
                        if aFeature.hasTrackingFrameCount() {
                            if aFeature.trackingFrameCount() <= 1 {
                                resetNewFaces = true
                            }
                        }

                }

        }
        if resetNewFaces { currentFeatureIndex = 0 }

    }

    func setOutputAttributes(wrapperFilter: PGLDissolveWrapperFilter) {
        // may not need to be type PGLDissolveWrapperFilter
        // as it just outputs  from input & target attributes
        targetInputAttribute = wrapperFilter.imageInputAttribute()
        targetInputTargetAttribute = wrapperFilter.imageTargetImageAttribute()


    }



    func featureImagePair() ->(inputFeature: CIImage, targetFeature: CIImage) {
        // PGLDetector
        // used for the first setup of the dissolve wrapper
        // answers the internal filter output with two images for a dissolve
        // the dissolve uses inputImage and targetImage
        // current two features are used to set the input attrbute point
        // uses currentFeatureIndex. should increment on increment intervals
        let restoreIndex = currentFeatureIndex
        setFeaturePoint()
        let inputDissolveImage = localFilter?.outputImage
        nextFeature(to: Direction.forward) // moves featureIndex forward or back to zero for looping
        setFeaturePoint()
        let targetDissolveImage = localFilter?.outputImage
        currentFeatureIndex = restoreIndex
        return (inputDissolveImage ?? CIImage.empty(),targetDissolveImage ?? CIImage.empty())
    }

    func nextImage() -> CIImage {
        increment()
        setFeaturePoint()
        return localFilter?.outputImage ?? CIImage.empty()
    }

    func isEven() -> Bool {
        // answers true if the currentFeatureIndex is zero or an even number

        return currentFeatureIndex.isEven()

    }

    // MARK: Output
    func outputFeatureImages() -> [CIImage] {
        // answer a collection of images starting without features and then each feature highlighted.
        var answerImages = [CIImage]()
        guard inputImage != nil  // features are not highlighted
            else { return answerImages }

//        answerImages.append(startImage) // put the unaltered image first}

        if let myFaceFilter = localFilter as? PGLFilterCIAbstract {
            guard let myDisplayFeatures = self.displayFeatures
                else { return answerImages }
            myFaceFilter.features = features
            myFaceFilter.displayFeatures = myDisplayFeatures
            myFaceFilter.inputImage = inputImage
                // updateValue(value, forKey: kCIInputImageKey)
            for i in myDisplayFeatures {
                myFaceFilter.inputFeatureSelect = i
                if let thisFeatureImage = myFaceFilter.outputImage {
                    answerImages.append(thisFeatureImage)
                }
            }
        } else {
            // not a PGLFilterCIAbstract..which has features set by the detector
             // here set the the attribute to the feature point and output an image
            let restoreIndex = currentFeatureIndex
            for i in 0..<features.count {
                currentFeatureIndex = i
                setFeaturePoint()
                answerImages.append((localFilter?.outputImage)!)
            }
            currentFeatureIndex = restoreIndex

            
        }

        return answerImages
    }


}



class PGLRectangleFilter : PGLSourceFilter {
    // applies CIImage level methods to the image output



    var cropAttribute: PGLAttributeRectangle? {
        didSet{
//            if cropAttribute == nil { fatalError("PGLRectangleFilter cropAttribute set to nil ")}
//            NSLog("PGLRectangleFilter didSet var cropAttribute = \(cropAttribute)")
        }
    }

   override func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {
        // RectangleFilter needs to crop then scale to full size
        // Most filters do not need this. Parnent PGLSourceFilter has empty implementation
          //ciOutputImage.extent    CGRect    (origin = (x = 592, y = 491), size = (width = 729, height = 742))
        // currentStack.cropRect    CGRect    (origin = (x = 0, y = 0), size = (width = 1583, height = 1668))
        let widthScale = stackCropRect.width / ciOutput.extent.width
        let heightScale = stackCropRect.height / ciOutput.extent.height

        let scaleTransform = CGAffineTransform(scaleX: widthScale, y: heightScale)
        let translate = scaleTransform.translatedBy(x: -ciOutput.extent.minX, y: -ciOutput.extent.minY)

        return ciOutput.transformed(by: translate)
    }


    override func outputImage() -> CIImage? {
        let thisOutput = super.outputImage()
        return thisOutput
        // need the transform for aspectFit to the parent extent.
//        if let newOutput = thisOutput {
////        let parentExtent = outputExtent()
//        let widthScale = parentExtent.width / newOutput.extent.width  //CGFloat
//        let heightScale = parentExtent.height / newOutput.extent.height
//
//        let scale = min(widthScale,heightScale)  // this is aspectFit
//                // aspectFill use max instead of min
//        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
//            return newOutput.transformed(by: scaleTransform)
//        } else {
//            return thisOutput  // nil check else condition
//        }


    }

    override func setInput(image: CIImage?, source: String?) {
        super.setInput(image: image, source: source)

    }

    func attributeCropRect() -> CGRect {
        // answer the attributes filter rect
        return (cropAttribute?.filterRect)!
    }

   
}


class PGLDetectorFilter: PGLSourceFilter {
    // move down the detector[] array here?
    required init?(filter: String, position: PGLFilterCategoryIndex) {
      super.init(filter: filter, position: position)
     hasAnimation = true
        detectors.append( DetectorFramework.Active.init(ciFilter: PGLFaceCIFilter()))

    }

    override func setCIContext(detectorContext: CIContext?) {
        for thisDetector in detectors {
            // pass on the context for the  detectorFilter.detector
            thisDetector.setCIContext(detectorContext: detectorContext)
        }
    }

}

class PGLFilterConstructor: CIFilterConstructor {
    //MARK: CIFilterConstructor protocol
    // see also the PGLFilterDescriptor method filter() -> CIFilter

    func filter(withName: String) -> CIFilter? {

        switch withName {
            case kPBumpBlend :
                return PGLBumpBlendCI()

            case kPBumpFace:
                return PGLBumpFaceCIFilter()
            case kPFaceFilter:
                    return PGLFaceCIFilter()
            case kPImages :
                    return PGLImageCIFilter()


//            case kPCarnivalMirror:
//                return PGLCarnivalMirror()
            case kPTiltShift :
                return PGLTiltShift()

            case kPWarpItMetal :
                return WarpItMetalFilter()

            case kCompositeTextPositionFilter:
//                return PGLTextImageGenerator.internalCIFilter()
                return CompositeTextPositionFilter()

            case kSaliencyBlurFilter:
                return PGLSaliencyBlurFilter()

            default:
                return CIFilter(name: withName)!
        }
    }

}





