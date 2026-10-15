import Foundation
import Operation_iOS

struct SubtensorFlowServices {
    let account: MetaChainAccountResponse
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signer: SigningWrapperProtocol
    let operationService: SubtensorStakingOperationServiceProtocol
    let preflightFactory: SubtensorPreflightFactoryProtocol
    let tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue

    func isFlowAccount(_ other: MetaChainAccountResponse) -> Bool {
        other.metaId == account.metaId && other.chainAccount.accountId == account.chainAccount.accountId
    }
}

enum SubtensorFlowServicesFactory {
    static func createServices(for state: SubtensorStakingSharedStateProtocol) -> SubtensorFlowServices? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let account = state.selectedAccount,
            let positionsSyncService = state.positionsSyncService,
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = createExtrinsicService(
            for: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        let extrinsicSubmitMonitor = createSubmitMonitor(
            for: extrinsicService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        let signer = createSigner(for: account)

        guard let operationService = try? state.createStakingOperationService(
            for: account.chainAccount.accountId,
            extrinsicService: extrinsicService,
            extrinsicSubmitMonitor: extrinsicSubmitMonitor,
            signer: signer
        ) else {
            return nil
        }

        return SubtensorFlowServices(
            account: account,
            positionsSyncService: positionsSyncService,
            runtimeProvider: runtimeProvider,
            extrinsicService: extrinsicService,
            extrinsicSubmitMonitor: extrinsicSubmitMonitor,
            signer: signer,
            operationService: operationService,
            preflightFactory: createPreflightFactory(for: state, operationQueue: operationQueue),
            tradeQuoteFactory: state.earnServices.tradeQuoteFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

private extension SubtensorFlowServicesFactory {
    static func createSigner(for account: MetaChainAccountResponse) -> SigningWrapperProtocol {
        SigningWrapperFactory().createSigningWrapper(
            for: account.metaId,
            accountResponse: account.chainAccount
        )
    }

    static func createExtrinsicService(
        for account: MetaChainAccountResponse,
        chain: ChainModel,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) -> ExtrinsicServiceProtocol {
        ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(
            account: account.chainAccount,
            chain: chain
        )
    }

    static func createSubmitMonitor(
        for extrinsicService: ExtrinsicServiceProtocol,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) -> ExtrinsicSubmitMonitorFactoryProtocol {
        ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: ExtrinsicStatusService(
                connection: connection,
                runtimeProvider: runtimeProvider,
                eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
                logger: Logger.shared
            ),
            operationQueue: operationQueue
        )
    }

    static func createPreflightFactory(
        for state: SubtensorStakingSharedStateProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorPreflightFactoryProtocol {
        let chainId = state.stakingOption.chainAsset.chain.chainId

        return SubtensorPreflightFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chainId,
                chainRegistry: state.chainRegistry
            ),
            operationQueue: operationQueue
        )
    }
}
