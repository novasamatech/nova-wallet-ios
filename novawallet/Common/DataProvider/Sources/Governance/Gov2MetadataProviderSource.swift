import Foundation
import RobinHood

final class Gov2MetadataProviderSource: SingleValueProviderSourceProtocol {
    typealias Model = ReferendumMetadataMapping

    func fetchOperation() -> CompoundOperationWrapper<ReferendumMetadataMapping?> {
        CompoundOperationWrapper.createWithResult([:])
    }
}
