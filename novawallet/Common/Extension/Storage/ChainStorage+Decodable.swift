import Foundation
import SubstrateSdk
import Operation_iOS

extension AnyDataProviderRepository where AnyDataProviderRepository.Model == ChainStorageItem {
    func queryStorageByKey<T: ScaleDecodable>(_ identifier: String) -> CompoundOperationWrapper<T?> {
        let fetchOperation = self.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let decoderOperation = ScaleDecoderOperation<T>()
        decoderOperation.configurationBlock = {
            do {
                decoderOperation.data = try fetchOperation
                    .extractNoCancellableResultData()?
                    .data
            } catch {
                decoderOperation.result = .failure(error)
            }
        }

        decoderOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: decoderOperation,
            dependencies: [fetchOperation]
        )
    }
}
