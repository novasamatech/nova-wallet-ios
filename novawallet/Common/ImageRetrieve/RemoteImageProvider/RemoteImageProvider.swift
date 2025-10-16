import Kingfisher
import Operation_iOS
import UIKit

protocol RemoteImageProvider {
    associatedtype ImageInfo

    func downloadImageOperation(using imageInfo: ImageInfo) -> BaseOperation<UIImage>
}
