import Foundation
import Operation_iOS

final class AssetsHubExchangeProvider: AssetsExchangeBaseProvider {
    let chainRegistry: ChainRegistryProtocol

    private var supportedChains: [ChainModel.Id: ChainModel]?
    let wallet: MetaAccountModel
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let userStorageFacade: StorageFacadeProtocol

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.signingWrapperFactory = signingWrapperFactory
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade

        super.init(
            operationQueue: operationQueue,
            syncQueue: DispatchQueue(label: "io.novawallet.assetshubprovider.\(UUID().uuidString)"),
            logger: logger
        )
    }

    private func updateStateIfNeeded() {
        guard let supportedChains else {
            return
        }

        let exchanges: [AssetsExchangeProtocol] = supportedChains.values.compactMap { chain in
            guard
                let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
                let connection = chainRegistry.getConnection(for: chain.chainId),
                let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
                logger.warning("Wallet, Connection or runtime unavailable for \(chain.name)")
                return nil
            }

            let extrinsicOperationFactory = ExtrinsicServiceFactory(
                runtimeRegistry: runtimeService,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: substrateStorageFacade
            ).createOperationFactory(
                account: selectedAccount,
                chain: chain,
                customFeeEstimatingFactory: AssetExchangeFeeEstimatingFactory(
                    graphProxy: graphProxy,
                    operationQueue: operationQueue
                )
            )

            let signingWrapper = signingWrapperFactory.createSigningWrapper(
                for: selectedAccount.metaId,
                accountResponse: selectedAccount
            )

            let host = AssetHubExchangeHost(
                chain: chain,
                selectedAccount: selectedAccount,
                extrinsicOperationFactory: extrinsicOperationFactory,
                signingWrapper: signingWrapper,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            )

            return AssetsHubExchange(host: host)
        }

        updateState(with: exchanges)
    }

    private func handleChains(changes: [DataProviderChange<ChainModel>]) -> Bool {
        let updatedChains = changes.reduce(into: supportedChains ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.chainId] = newItem.hasSwapHub ? newItem : nil
            case let .delete(deletedIdentifier):
                accum[deletedIdentifier] = nil
            }
        }

        guard supportedChains != updatedChains else {
            return false
        }

        supportedChains = updatedChains

        return true
    }

    // MARK: Subsclass

    override func performSetup() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: syncQueue,
            filterStrategy: nil
        ) { [weak self] changes in
            guard let self, handleChains(changes: changes) else {
                return
            }

            updateStateIfNeeded()
        }
    }

    override func performThrottle() {
        chainRegistry.chainsUnsubscribe(self)
    }
}
