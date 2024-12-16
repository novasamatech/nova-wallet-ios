import Foundation
import Operation_iOS

struct PayCardHtmlResource {
    let url: URL
}

protocol PayCardResourceProviding {
    func loadResourceWrapper() -> CompoundOperationWrapper<PayCardHtmlResource>
}
