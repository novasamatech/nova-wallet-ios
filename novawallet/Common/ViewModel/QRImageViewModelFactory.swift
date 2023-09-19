import UIKit

protocol QRImageViewModelFactoryProtocol {
    func createViewModel(from images: [UIImage]) -> QRImageViewModel?
}

final class QRImageViewModelFactory {
    let durationPerFrame: TimeInterval

    init(durationPerFrame: TimeInterval = 0.1) {
        self.durationPerFrame = durationPerFrame
    }
}

extension QRImageViewModelFactory: QRImageViewModelFactoryProtocol {
    func createViewModel(from images: [UIImage]) -> QRImageViewModel? {
        guard !images.isEmpty else {
            return nil
        }

        if images.count > 1 {
            return .animated(.init(images: images, durationPerFrame: durationPerFrame))
        } else {
            return .single(images[0])
        }
    }
}
