import UIKit

extension UIImage {
    func blurred(with radius: CGFloat) -> UIImage? {
        guard let ciImg = CIImage(image: self) else { return nil }

        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(ciImg, forKey: kCIInputImageKey)
        blur?.setValue(radius, forKey: kCIInputRadiusKey)

        let context = CIContext()

        guard
            let resultImage = blur?.outputImage,
            let cgImage = context.createCGImage(resultImage, from: resultImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
