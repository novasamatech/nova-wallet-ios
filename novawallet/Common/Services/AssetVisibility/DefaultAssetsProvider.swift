import Foundation
import Operation_iOS
import Keystore_iOS

protocol DefaultAssetsProviding {
    var cachedDefaultAssets: DefaultAssetsList? { get }
    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList>
    func createRefreshDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList>
}

extension DefaultAssetsProviding {
    var cachedDefaultAssets: DefaultAssetsList? { nil }

    func createRefreshDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        createDefaultAssetsWrapper()
    }
}

final class DefaultAssetsProvider {
    let url: URL
    let dataOperationFactory: DataOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol
    let settingsManager: SettingsManagerProtocol

    @Atomic(defaultValue: nil)
    private var cached: DefaultAssetsList?

    init(
        url: URL,
        dataOperationFactory: DataOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        settingsManager: SettingsManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.url = url
        self.dataOperationFactory = dataOperationFactory
        self.chainRegistry = chainRegistry
        self.settingsManager = settingsManager
        self.logger = logger
    }
}

// MARK: DefaultAssetsProviding

extension DefaultAssetsProvider: DefaultAssetsProviding {
    var cachedDefaultAssets: DefaultAssetsList? {
        if let cached {
            return cached
        }

        guard let data = settingsManager.defaultAssetsConfiguration else {
            return nil
        }

        let list = extractList(from: data)

        guard !list.isEmpty else {
            return nil
        }

        cached = list
        return list
    }

    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        if let cached = cachedDefaultAssets {
            return CompoundOperationWrapper.createWithResult(cached)
        }

        return createRefreshDefaultAssetsWrapper()
    }

    func createRefreshDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        let fetchOperation = dataOperationFactory.fetchData(from: url)

        let mapOperation = ClosureOperation<DefaultAssetsList> { [weak self] in
            guard let self else {
                return .empty
            }

            do {
                let data = try fetchOperation.extractNoCancellableResultData()
                let list = extractList(from: data)

                guard !list.isEmpty else {
                    return cachedDefaultAssets ?? .empty
                }

                settingsManager.defaultAssetsConfiguration = data
                cached = list
                return list
            } catch {
                logger.error("Default assets config is unavailable: \(error)")
                return cachedDefaultAssets ?? .empty
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}

// MARK: Private

private extension DefaultAssetsProvider {
    func extractList(from data: Data) -> DefaultAssetsList {
        do {
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
