import Foundation
import Kingfisher
import Operation_iOS

protocol IconRetrieveOperationFactoryProtocol {
    func checkCacheOperation(using cacheKey: String) -> ClosureOperation<Bool>

    func downloadImageOperation(
        using logoInfo: IconInfo
    ) -> AsyncClosureOperation<UIImage>

    func retrieveImageOperation(using cacheKey: String) -> AsyncClosureOperation<UIImage>
}

enum ImageRetrievingError: Error {
    case logoDownloadError
    case logoRetrievingError
}
