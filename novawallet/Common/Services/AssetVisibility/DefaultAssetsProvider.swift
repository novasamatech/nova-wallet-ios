import Foundation
import Operation_iOS

protocol DefaultAssetsProviding {
    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList>
}

final class DefaultAssetsProvider {
    let url: URL
    let dataOperationFactory: DataOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    @Atomic(defaultValue: nil)
    private var cached: DefaultAssetsList?

    init(
        url: URL,
        dataOperationFactory: DataOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) {
        self.url = url
        self.dataOperationFactory = dataOperationFactory
        self.chainRegistry = chainRegistry
        self.logger = logger
    }
}

// MARK: DefaultAssetsProviding

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

// MARK: Private

private extension DefaultAssetsProvider {
    func extractList(from fetchOperation: BaseOperation<Data>) -> DefaultAssetsList {
        do {
            let data = try fetchOperation.extractNoCancellableResultData()
            let remote = try JSONDecoder().decode(DefaultAssetsRemote.self, from: data)

            guard remote.effectiveVersion == DefaultAssetsRemote.supportedVersion else {
                logger.error("Unsupported default assets config version: \(remote.effectiveVersion)")
                return .empty
            }

            let resolvedIds = remote.defaultAssets.compactMap { remoteAsset -> ChainAssetId? in
                let id = ChainAssetId(chainId: remoteAsset.chainId, assetId: remoteAsset.assetId)

                guard chainRegistry.getChain(for: id.chainId)?.chainAsset(for: id.assetId) != nil else {
                    return nil
                }

                return id
            }
            let list = DefaultAssetsList(ids: resolvedIds)

            guard !list.isEmpty else {
                logger.error("Default assets config resolves to no local assets")
                return .empty
            }

            return list
        } catch {
            logger.error("Default assets config is unavailable: \(error)")
            return .empty
        }
    }
}
