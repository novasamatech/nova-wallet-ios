import UIKit

enum QRImageViewModel {
    case single(UIImage)
    case animated(AnimatedImageViewModel)
}

extension UIImageView {
    func bindQr(viewModel: QRImageViewModel?) {
        stopAnimating()

        image = nil
        animationImages = nil

        switch viewModel {
        case let .single(image):
            self.image = image
        case let .animated(viewModel):
            animationImages = viewModel.images
            animationDuration = TimeInterval(viewModel.images.count) * viewModel.durationPerFrame
            animationRepeatCount = 0

            startAnimating()
        case nil:
            break
        }
    }
}
