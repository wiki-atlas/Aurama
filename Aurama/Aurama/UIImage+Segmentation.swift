

import UIKit
import VideoToolbox

extension UIImage {
    
    public func segmentation() -> (CGImage?, Double, Double)? {
        guard var (cgImage, position_x, position_y) = self.coarseSegmentation() else {
            return (nil, 0.0, 0.0)
        }
        let outputWidth:CGFloat = 500.0
        let outputSize = CGSize(width: outputWidth, height: outputWidth * (self.size.height / self.size.width))
        let resizeImg = UIImage(cgImage: cgImage!).resize(size: outputSize)!
        let ciImg = CIImage(cgImage: resizeImg.cgImage!)
        let smoothFilter = SmoothFilter.init()
        smoothFilter.inputImage = ciImg
 
        let outputImage = smoothFilter.outputImage!
        let ciContext = CIContext(options: nil)
        cgImage = ciContext.createCGImage(outputImage, from: ciImg.extent)!
        return (cgImage, position_x, position_y)
    }
    
    public func coarseSegmentation() -> (CGImage?, Double, Double)? {
        let deeplab = cityscapes.init()
        //input size 513*513
        let pixBuf = self.pixelBuffer(width: 384, height: 384)
        
        guard let output = try? deeplab.prediction(input_1: pixBuf!) else {
            return (nil, 0.0, 0.0)
        }
        
        let shape = output.up_sampling2d_2.shape
        let (d,w,h) = (Int(truncating: shape[0]), Int(truncating: shape[1]), Int(truncating: shape[2]))
        let pageSize = w*h
        var res:Array<Int> = []
        var pageIndexs:Array<Int> = []
        for i in 0..<d {
            pageIndexs.append(pageSize * i)
        }
 
        func argmax(arr:Array<Int>) -> Int{
            precondition(arr.count > 0)
            var maxValue = arr[0]
            var maxValueIndex = 0
            for i in 1..<arr.count {
                if arr[i] > maxValue {
                    maxValue = arr[i]
                    maxValueIndex = i
                }
            }
            return maxValueIndex
        }
        
        for i in 0..<w {
            for j in 0..<h {
                var itemArr:Array<Int> = []
                let pageOffset = i * w + j
                for k in 0..<d {
                    let padding = pageIndexs[k]
                    itemArr.append(Int(truncating: output.up_sampling2d_2[padding + pageOffset]))
                }
                /*
                types map  [
                    'background', 'aeroplane', 'bicycle', 'bird', 'boat', 'bottle', 'bus',
                    'car', 'cat', 'chair', 'cow', 'diningtable', 'dog', 'horse', 'motorbike',
                    'person', 'pottedplant', 'sheep', 'sofa', 'train', 'tv'
                    ]
                 */
                let type = argmax(arr: itemArr)
                res.append(type)
            }
        }
        
        let bytesPerComponent = MemoryLayout<UInt8>.size
        let bytesPerPixel = bytesPerComponent * 4
        let length = pageSize * bytesPerPixel
        var data = Data(count: length)
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
            var pointer = bytes
            /*
            This reserved only [cat,dog,person]
            */
            let reserve = [2]
            for pix in res{
                let v:UInt8 = reserve.contains(pix) ? 255 : 0
                for _ in 0...3 {
                    pointer.pointee = v
                    pointer += 1
                }
            }
        }
        
        var x_weights: Double = 0
        var y_weights: Double = 0
        var count: Double = 0
        for i in 0...383 {
            for j in 0...383{
                if res[i * 384 + j] == 2 {
                    y_weights += Double(i)
                    x_weights += Double(j)
                    count += 1
                }
            }
        }
        
        let position_x = x_weights / 384.0 / count
        let position_y = y_weights / 384.0 / count
        
        //print(position_x)
        //print(position_y)
        
        let provider: CGDataProvider = CGDataProvider(data: data as CFData)!
        let cgimg = CGImage(
            width: w,
            height: h,
            bitsPerComponent: bytesPerComponent * 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerPixel * w,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: CGColorRenderingIntent.defaultIntent
            )
        return (cgimg, position_x, position_y)
    }
}

extension UIImage {

  public func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    return pixelBuffer(width: width, height: height,
                       pixelFormatType: kCVPixelFormatType_32ARGB,
                       colorSpace: CGColorSpaceCreateDeviceRGB(),
                       alphaInfo: .noneSkipFirst)
  }
 
  func pixelBuffer(width: Int, height: Int, pixelFormatType: OSType,
                   colorSpace: CGColorSpace, alphaInfo: CGImageAlphaInfo) -> CVPixelBuffer? {
    var maybePixelBuffer: CVPixelBuffer?
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     width,
                                     height,
                                     pixelFormatType,
                                     attrs as CFDictionary,
                                     &maybePixelBuffer)

    guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)

    guard let context = CGContext(data: pixelData,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                  space: colorSpace,
                                  bitmapInfo: alphaInfo.rawValue)
    else {
      return nil
    }

    UIGraphicsPushContext(context)
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    return pixelBuffer
  }
}

extension UIImage {
    
    func resize(size: CGSize!) -> UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        self.draw(in:rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
    
    
 
}

extension UIImage {
    func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return image
    }

    func normalized() -> [Float32]? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        let w = cgImage.width
        let h = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let bitsPerComponent = 8
        var rawBytes: [UInt8] = [UInt8](repeating: 0, count: w * h * 4)
        rawBytes.withUnsafeMutableBytes { ptr in
            if let cgImage = self.cgImage,
                let context = CGContext(data: ptr.baseAddress,
                                        width: w,
                                        height: h,
                                        bitsPerComponent: bitsPerComponent,
                                        bytesPerRow: bytesPerRow,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                let rect = CGRect(x: 0, y: 0, width: w, height: h)
                context.draw(cgImage, in: rect)
            }
        }
        var normalizedBuffer: [Float32] = [Float32](repeating: 0, count: w * h * 3)
        // normalize the pixel buffer
        // see https://pytorch.org/hub/pytorch_vision_resnet/ for more detail
        for i in 0 ..< w * h {
            normalizedBuffer[i] = (Float32(rawBytes[i * 4 + 0]) / 255.0 - 0.485) / 0.229 // R
            normalizedBuffer[w * h + i] = (Float32(rawBytes[i * 4 + 1]) / 255.0 - 0.456) / 0.224 // G
            normalizedBuffer[w * h * 2 + i] = (Float32(rawBytes[i * 4 + 2]) / 255.0 - 0.406) / 0.225 // B
        }
        return normalizedBuffer
    }
}



fileprivate class SmoothFilter : CIFilter {
    
    private let kernel: CIColorKernel
    var inputImage: CIImage?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init() {
        let kernelStr = """
            kernel vec4 myColor(__sample source) {
                float maskValue = smoothstep(0.3, 0.5, source.r);
                return vec4(maskValue,maskValue,maskValue,1.0);
            }
        """
        let kernels = CIColorKernel.makeKernels(source:kernelStr)!
        kernel = kernels[0] as! CIColorKernel
        super.init()
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else {return nil}
        let blurFilter = CIFilter.init(name: "CIGaussianBlur")!
        blurFilter.setDefaults()
        blurFilter.setValue(inputImage.extent.width / 90.0, forKey: kCIInputRadiusKey)
        blurFilter.setValue(inputImage, forKey: kCIInputImageKey)
        let bluredImage = blurFilter.value(forKey:kCIOutputImageKey) as! CIImage
        return kernel.apply(extent: bluredImage.extent, arguments: [bluredImage])
    }
}
