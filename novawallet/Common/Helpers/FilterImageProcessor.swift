import Foundation
import Kingfisher

final class FilterImageProcessor: ImageProcessor {
    var identifier: String { proccessor.identifier }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(kFCrossPlatformImage):
            guard filterClosure(kFCrossPlatformImage) else {
                return kFCrossPlatformImage
            }

            return proccessor.process(item: item, options: options)
        case .data:
            return proccessor.process(item: item, options: options)
        }
    }

    let filterClosure: (KFCrossPlatformImage) -> Bool
    let proccessor: ImageProcessor

    init(proccessor: ImageProcessor, filter: @escaping (KFCrossPlatformImage) -> Bool) {
        self.proccessor = proccessor
        filterClosure = filter
    }
}
