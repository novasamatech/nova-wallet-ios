import Foundation
import Operation_iOS

final class OffchainMultisigOperationsFactoryFacade {
    let configProvider: GlobalConfigProviding
    let operationManager: OperationManagerProtocol

    let chainId: ChainModel.Id

    init(
        configProvider: GlobalConfigProviding,
        chainId: ChainModel.Id,
        operationManager: OperationManagerProtocol
    ) {
        self.configProvider = configProvider
        self.chainId = chainId
        self.operationManager = operationManager
    }
}

extension OffchainMultisigOperationsFactoryFacade: OffchainMultisigOperationsFactoryProtocol {
    func createFetchOffChainOperationInfo(
        for accountId: AccountId,
        callHashes: Set<Substrate.CallHash>
    ) -> CompoundOperationWrapper<[Substrate.CallHash: OffChainMultisigInfo]> {
        let configWrapper = configProvider.createConfigWrapper()

        let requestWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [chainId] in
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            let operationFactory = OffchainMultisigOperationsFactory(
                url: config.multisigsApiUrl,
                chainId: chainId
            )

            return operationFactory.createFetchOffChainOperationInfo(
                for: accountId,
                callHashes: callHashes
            )
        }

        requestWrapper.addDependency(wrapper: configWrapper)

        return requestWrapper.insertingHead(operations: configWrapper.allOperations)
    }
}
