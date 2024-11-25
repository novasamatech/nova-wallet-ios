import WebKit
import UIKit

extension UIView {
    func createStateRenderImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { layer.render(in: $0.cgContext) }

        return image
    }
}
