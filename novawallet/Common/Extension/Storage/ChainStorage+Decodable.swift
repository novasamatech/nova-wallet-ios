import Foundation
import SubstrateSdk
import Operation_iOS

extension AnyDataProviderRepository where AnyDataProviderRepository.Model == ChainStorageItem {
    func queryStorageByKey<R: ScaleDecodable>(_ identifier: String) -> CompoundOperationWrapper<R?> {
        let fetchOperation = self.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let decoderOperation = ScaleDecoderOperation<R>()
        decoderOperation.configurationBlock = {
            do {
                decoderOperation.data = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?
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
