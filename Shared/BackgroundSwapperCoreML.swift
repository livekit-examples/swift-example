//import WebRTC
//import LiveKit
//import Vision
//import CoreImage.CIFilterBuiltins
//
//class BackgroundSwapperCoreML {
//
////    lazy var model: VNCoreMLModel? = try? VNCoreMLModel(for: DeepLabV3(configuration: .init()).model)
//
//    // the image used for background, if nil bg will not be swapped
//    var backgroundImage: CIImage?
//
//    func process(frame: RTCVideoFrame, capture: @escaping CaptureFunc) {
//
//        guard let backgroundImage = backgroundImage else {
//            // if image is nil (no bg swapping), simply use the input frame
//            capture(frame)
//            return
//        }
//
//        guard let pixelBuffer = (frame.buffer as? RTCCVPixelBuffer)?.pixelBuffer else {
//            // buffer is not a RTCCVPixelBuffer
//            capture(frame)
//            return
//        }
//        
////        guard let model = model else {
////            capture(frame)
////            return
////        }
//        
////        let request = VNCoreMLRequest(model: model, completionHandler: { request, error in
////
////            guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
////                  let segmentationmap = observations.first?.featureValue.multiArrayValue else {
////                      return
////                  }
//            
//            // too slow
////            guard let cgImage = segmentationmap.cgImage(min: 0, max: 1) else {
////                      return
////                  }
//////
////            print("did finish CoreML \(cgImage.width)x\(cgImage.height)")
//            
//            capture(frame)
//            
////            let maskImage = CIImage(cgImage: cgImage)
////
//////            let segmentationMask = segmentationmap.image(min: 0, max: 1)
////            //self.outputImage = segmentationMask!.resizedImage(for: self.inputImage.size)!
////
////            let originalImage = CIImage(cvPixelBuffer: pixelBuffer)
//////            var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
////
////            let blended = CIFilter(name: "CIBlendWithMask", parameters: [
////                                                    kCIInputImageKey: originalImage,
////                                                    kCIInputBackgroundImageKey: backgroundImage,
////                                                    kCIInputMaskImageKey: maskImage])?.outputImage
////            guard let blended = blended else {
////                return
////            }
////
////            if let newFrame = blended.toPixelBuffer()?.toRTCVideoFrame(timeStampNs: frame.timeStampNs) {
////                capture(newFrame)
////            }
//            
//        })
//                                    
////        request.imageCropAndScaleOption = .scaleFill
//        
//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//        
//        do {
//            try handler.perform([request])
//        }catch {
//            print(error)
//        }
//    }
//}
