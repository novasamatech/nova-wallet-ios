import Foundation
import Operation_iOS

struct PayCardResource {
    let url: URL
}

protocol PayCardResourceProviding {
    func loadResource(using params: MercuryoCardParams) throws -> PayCardResource
}
