import Foundation
import Operation_iOS

struct SubtensorFlowServices {
    let account: MetaChainAccountResponse
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let submissionOperationFactory: SubtensorSubmissionOperationFactoryProtocol
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
        for state: SubtensorSharedStateProtocol,
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

        guard let submissionOperationFactory = try? state.createSubmissionOperationFactory(
            for: account.chainAccount.accountId,
            extrinsicService: extrinsicService,
            extrinsicSubmitMonitor: extrinsicSubmitMonitor,
            signer: createSigner(for: account),
            shield: createShieldServices(for: account, state: state, sealer: MevShieldSealer())
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
        for state: SubtensorSharedStateProtocol
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

    static func createShieldServices(
        for account: MetaChainAccountResponse,
        state: SubtensorSharedStateProtocol,
        sealer: MevShieldSealing?
    ) -> SubtensorShieldServices? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        return createShieldServices(
            for: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            sealer: sealer
        )
    }

    static func createShieldServices(
        for account: MetaChainAccountResponse,
        chain: ChainModel,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        sealer: MevShieldSealing?
    ) -> SubtensorShieldServices? {
        guard let sealer, SubtensorShieldEligibility.supports(walletType: account.chainAccount.type) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let statusService = ExtrinsicStatusService(
            connection: connection,
            runtimeProvider: runtimeProvider,
            eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
            logger: Logger.shared
        )

        let extrinsicFactory = SubtensorShieldExtrinsicFactory(
            account: account.chainAccount,
            chain: chain,
            connection: connection,
            extrinsicServiceFactory: ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: UserDataStorageFacade.shared,
                substrateStorageFacade: SubstrateDataStorageFacade.shared
            ),
            keyOperationFactory: MevShieldOperationFactory(
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue
            ),
            sealer: sealer,
            operationQueue: operationQueue
        )

        let inclusionTracker = SubtensorShieldInclusionTracker(
            connection: connection,
            runtimeProvider: runtimeProvider,
            statusService: statusService,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
            operationQueue: operationQueue
        )

        let submissionFactory = SubtensorShieldSubmissionFactory(
            extrinsicFactory: extrinsicFactory,
            inclusionTracker: inclusionTracker,
            statusService: statusService,
            signerFactory: {
                SigningWrapperFactory().createAuthorizeOnceSigningWrapper(
                    for: account.metaId,
                    accountResponse: account.chainAccount,
                    signaturesPerAuthorization: SubtensorShieldConstants.signaturesPerOrder
                )
            },
            operationQueue: operationQueue
        )

        return SubtensorShieldServices(submissionFactory: submissionFactory, operationQueue: operationQueue)
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
        let walletType = account.chainAccount.type

        guard !FeatureSupportChecker.refusesSubtensorStakingSigning(for: walletType) else {
            return NoSigningSupportWrapper(type: walletType == .proxied ? .proxy : .ledger)
        }

        return SigningWrapperFactory().createSigningWrapper(
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
        for state: SubtensorSharedStateProtocol,
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
