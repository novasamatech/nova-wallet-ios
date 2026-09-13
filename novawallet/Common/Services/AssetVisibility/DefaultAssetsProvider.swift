import Foundation
import Operation_iOS

protocol DefaultAssetsProviding {
    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList>
}

final class DefaultAssetsProvider {
    let url: URL
    let dataOperationFactory: DataOperationFactoryProtocol
    let logger: LoggerProtocol

    @Atomic(defaultValue: nil)
    private var cached: DefaultAssetsList?

    init(
        url: URL,
        dataOperationFactory: DataOperationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.url = url
        self.dataOperationFactory = dataOperationFactory
        self.logger = logger
    }
}

private extension DefaultAssetsProvider {
    func extractList(from fetchOperation: BaseOperation<Data>) -> DefaultAssetsList {
        do {
            let data = try fetchOperation.extractNoCancellableResultData()
            let remote = try JSONDecoder().decode(DefaultAssetsRemote.self, from: data)
            let list = DefaultAssetsList(remote: remote)

            guard !list.isEmpty else {
                logger.error("Default assets config declares no assets")
                return .empty
            }

            return list
        } catch {
            logger.error("Default assets config is unavailable: \(error)")
            return .empty
        }
    }
}

extension DefaultAssetsProvider: DefaultAssetsProviding {
    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        if let cached {
            return CompoundOperationWrapper.createWithResult(cached)
        }

        let fetchOperation = dataOperationFactory.fetchData(from: url)

        let mapOperation = ClosureOperation<DefaultAssetsList> { [weak self] in
            guard let self else {
                return .empty
            }

            let list = extractList(from: fetchOperation)

            if !list.isEmpty {
                cached = list
            }

            return list
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
