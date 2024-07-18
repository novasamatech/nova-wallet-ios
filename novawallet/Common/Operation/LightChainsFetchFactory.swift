import Foundation
import Operation_iOS

protocol LightChainsFetchFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<[LightChainModel]>
}

class LightChainsFetchFactory {
    private let dataFetchFactory: DataOperationFactoryProtocol

    init(dataFetchFactory: any DataOperationFactoryProtocol) {
        self.dataFetchFactory = dataFetchFactory
    }
}

extension LightChainsFetchFactory: LightChainsFetchFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<[LightChainModel]> {
        let fetchOperation = dataFetchFactory.fetchData(from: ApplicationConfig.shared.preConfiguredLightChainListURL)

        let mapOperation = ClosureOperation<[LightChainModel]> {
            let remoteData = try fetchOperation.extractNoCancellableResultData()

            return try JSONDecoder().decode(
                [LightChainModel].self,
                from: remoteData
            )
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }
}
