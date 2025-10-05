import Foundation
import Keystore_iOS
import Operation_iOS

protocol AHMFullInfoFactoryProtocol {
    func fetch(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMFullInfo?>
}

final class AHMFullInfoFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let ahmInfoRepository: AHMInfoRepositoryProtocol
    private let filterSetKeypath: FilterSetKeyPath?

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        settingsManager: SettingsManagerProtocol = SettingsManager.shared,
        ahmInfoRepository: AHMInfoRepositoryProtocol = AHMInfoRepository.shared,
        filterSetKeypath: FilterSetKeyPath? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.settingsManager = settingsManager
        self.ahmInfoRepository = ahmInfoRepository
        self.filterSetKeypath = filterSetKeypath
    }
}

// MARK: - Private

private extension AHMFullInfoFactory {
    func checkFetchAvailable(for chainId: ChainModel.Id) -> Bool {
        let migrationEnded = settingsManager.ahmInfoShownChains.chainIds.contains(chainId)
        let checkedByUser: Bool = if let filterSetKeypath {
            settingsManager[keyPath: filterSetKeypath].chainIds.contains(chainId)
        } else {
            false
        }

        return migrationEnded && !checkedByUser
    }
}

// MARK: - AHMFullInfoFactoryProtocol

extension AHMFullInfoFactory: AHMFullInfoFactoryProtocol {
    func fetch(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMFullInfo?> {
        guard checkFetchAvailable(for: chainId) else {
            return .createWithResult(nil)
        }

        let infoFetchWrapper = ahmInfoRepository.fetch(by: chainId)

        let mapOperation = ClosureOperation<AHMFullInfo?> { [weak self] in
            guard
                let self,
                let info = try infoFetchWrapper.targetOperation.extractNoCancellableResultData()
            else {
                return nil
            }

            let sourceChain = try chainRegistry.getChainOrError(for: info.sourceData.chainId)
            let destinationChain = try chainRegistry.getChainOrError(for: info.destinationData.chainId)

            guard let asset = sourceChain.asset(for: info.sourceData.assetId) else {
                return nil
            }

            return AHMFullInfo(
                info: info,
                sourceChain: sourceChain,
                destinationChain: destinationChain,
                asset: asset
            )
        }

        mapOperation.addDependency(infoFetchWrapper.targetOperation)

        return infoFetchWrapper.insertingTail(operation: mapOperation)
    }
}

// MARK: - Internal types

extension AHMFullInfoFactory {
    typealias FilterSetKeyPath = KeyPath<
        SettingsManagerProtocol,
        AHMInfoExcludedChains
    >
}
