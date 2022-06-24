import Foundation
import RobinHood

protocol AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo>
}

final class AssetStorageInfoOperationFactory {}

extension AssetStorageInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol {
    func createStorageInfoWrapper(
        from asset: AssetModel,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let infoExtractionOperation = ClosureOperation<AssetStorageInfo> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try AssetStorageInfo.extract(from: asset, codingFactory: codingFactory)
        }

        infoExtractionOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: infoExtractionOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}
