/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import AVFoundation
import UIKit
import Accelerate

extension CVPixelBuffer {
  func normalize() {
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)
    
    CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)

    // MARK: TO_DO
    var minPixel: Float = 1.0  // change to Float16 in Swift 5.3 (Xcode 12, currently in beta 2020-09-12)
    var maxPixel: Float = 0.0
    
    /// You might be wondering why the for loops below use `stride(from:to:step:)`
    /// instead of a simple `Range` such as `0 ..< height`?
    /// The answer is because in Swift 5.1, the iteration of ranges performs badly when the
    /// compiler optimisation level (`SWIFT_OPTIMIZATION_LEVEL`) is set to `-Onone`,
    /// which is eactly what happens when running this sample project in Debug mode.
    /// If this was a production app then it might not be worth worrying about but it is still
    /// worth being aware of.
    
    for y in stride(from: 0, to: height, by: 1) {
      for x in stride(from: 0, to: width, by: 1) {
        let pixel = floatBuffer[y * width + x]
        minPixel = min(pixel, minPixel)
        maxPixel = max(pixel, maxPixel)
      }
    }
    
    let range = maxPixel - minPixel
    NSLog("CVPixelBuffer #normalize start maxPixel = \(maxPixel), min = \(minPixel) range = \(range)")
    for y in stride(from: 0, to: height, by: 1) {
      for x in stride(from: 0, to: width, by: 1) {
        let pixel = floatBuffer[y * width + x]
        floatBuffer[y * width + x] = (pixel - minPixel) / range
      }
    }

 // check for new values
     minPixel = 1.0
     maxPixel = 0.0
    for y in stride(from: 0, to: height, by: 1) {
      for x in stride(from: 0, to: width, by: 1) {
        let pixel = floatBuffer[y * width + x]
        minPixel = min(pixel, minPixel)
        maxPixel = max(pixel, maxPixel)
      }
    }
    let newRange = maxPixel - minPixel
     NSLog("CVPixelBuffer #normalize finish maxPixel = \(maxPixel), min = \(minPixel) range = \(newRange)")


    CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

  }

    func normalizeDSP() {
        // use the Accelerate vDSP_normalize demo in the
        // Accelerate Blur Detection sample app
        // change Float to Float16 in Swift 5.3 (Xcode 12, currently in beta 2020-09-12)
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let count = width * height

      CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
      let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)

        // from sample app AccelerateBlurDetection func processImage(data: ..)
//        floatPixels = [Float](unsafeUninitializedCapacity: count) {
//            buffer, initializedCount in
//
//            var floatBuffer = vImage_Buffer(data: buffer.baseAddress,
//                                            height: sourceBuffer.height,
//                                            width: sourceBuffer.width,
//                                            rowBytes: width * MemoryLayout<Float>.size)
//
//            vImageConvert_Planar8toPlanarF(&sourceBuffer,
//                                           &floatBuffer,
//                                           0, 255,
//                                           vImage_Flags(kvImageNoFlags))
//
//            initializedCount = count
//        }

        // Calculate standard deviation.
//               var mean = Float.nan
//               var stdDev = Float.nan
//
//               vDSP_normalize(floatPixels, 1,
//                              nil, 1,
//                              &mean, &stdDev,
//                              vDSP_Length(count))
    }
}
