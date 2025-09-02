import Kingfisher
import Operation_iOS

protocol RemoteImageProvider {
    associatedtype ImageInfo

    func downloadImageOperation(using imageInfo: ImageInfo) -> BaseOperation<UIImage>
}
