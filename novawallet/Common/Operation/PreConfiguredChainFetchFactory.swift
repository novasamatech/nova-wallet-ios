import Foundation
import Operation_iOS

protocol PreConfiguredChainFetchFactoryProtocol {
    func createWrapper(with chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel>
}

class PreConfiguredChainFetchFactory {
    private let dataFetchFactory: DataOperationFactoryProtocol

    init(dataFetchFactory: any DataOperationFactoryProtocol) {
        self.dataFetchFactory = dataFetchFactory
    }
}

extension PreConfiguredChainFetchFactory: PreConfiguredChainFetchFactoryProtocol {
    func createWrapper(with chainId: ChainModel.Id) -> CompoundOperationWrapper<ChainModel> {
        let directoryURL = ApplicationConfig.shared.preConfiguredChainDirectoryURL
        let chainURL = directoryURL.appendingPathComponent("\(chainId).json")

        let fetchOperation = dataFetchFactory.fetchData(from: chainURL)

        let mapOperation = ClosureOperation<ChainModel> {
            let remoteData = try fetchOperation.extractNoCancellableResultData()
            let remoteModel = try JSONDecoder().decode(
                RemoteChainModel.self,
                from: remoteData
            )

            let additionals = ChainModelConversionAdditionals(
                additionalAssets: [],
                order: 0
            )

            guard let chainModel = ChainModelConverter().update(
                localModel: nil,
                remoteModel: remoteModel,
                additionals: additionals
            ) else {
                throw CommonError.noDataRetrieved
            }

            return chainModel
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }
}
