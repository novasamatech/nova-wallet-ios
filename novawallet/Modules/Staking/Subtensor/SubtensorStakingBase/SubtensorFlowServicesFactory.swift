import Foundation
import Operation_iOS

struct SubtensorFlowServices {
    let account: MetaChainAccountResponse
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let submissionOperationFactory: SubtensorStakingSubmissionOperationFactoryProtocol
    let preflightOperationFactory: SubtensorPreflightOperationFactoryProtocol
    let tradeQuoteOperationFactory: SubtensorTradeQuoteOperationFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let blockNumberSubscription: BlockNumberRemoteSubscriptionProtocol?
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue

    func isFlowAccount(_ other: MetaChainAccountResponse) -> Bool {
        other.metaId == account.metaId && other.chainAccount.accountId == account.chainAccount.accountId
    }
}

enum SubtensorFlowServicesFactory {
    static func createServices(
        for state: SubtensorStakingSharedStateProtocol,
        observesBlocks: Bool = true
    ) -> SubtensorFlowServices? {
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

        guard let submissionOperationFactory = try? state.createSubmissionOperationFactory(
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
            submissionOperationFactory: submissionOperationFactory,
            preflightOperationFactory: createPreflightOperationFactory(for: state, operationQueue: operationQueue),
            tradeQuoteOperationFactory: state.earnServices.tradeQuoteOperationFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockNumberSubscription: observesBlocks ? createBlockSubscription(
                for: chain,
                connection: connection,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            ) : nil,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    static func createBlockSubscription(
        for state: SubtensorStakingSharedStateProtocol
    ) -> BlockNumberRemoteSubscriptionProtocol? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        return createBlockSubscription(
            for: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}

private extension SubtensorFlowServicesFactory {
    static func createBlockSubscription(
        for chain: ChainModel,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) -> BlockNumberRemoteSubscriptionProtocol {
        BlockNumberRemoteSubscription(
            chainId: chain.chainId,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            workingQueue: .main,
            localKeyFactory: LocalStorageKeyFactory()
        )
    }

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

    static func createPreflightOperationFactory(
        for state: SubtensorStakingSharedStateProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorPreflightOperationFactoryProtocol {
        let chain = state.stakingOption.chainAsset.chain

        return SubtensorPreflightOperationFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chain.chainId,
                chainRegistry: state.chainRegistry
            ),
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
            operationQueue: operationQueue
        )
    }
}
