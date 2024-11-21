import WebKit
import UIKit

extension WKWebView {
    func createStateRenderImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { layer.render(in: $0.cgContext) }

        return image
    }
}
