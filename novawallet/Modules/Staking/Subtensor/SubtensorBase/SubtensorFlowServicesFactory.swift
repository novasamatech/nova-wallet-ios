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

        guard let submissionOperationFactory = createSubmissionOperationFactory(
            for: account,
            state: state,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
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
}

private extension SubtensorFlowServicesFactory {
    static func createSubmissionOperationFactory(
        for account: MetaChainAccountResponse,
        state: SubtensorSharedStateProtocol,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorSubmissionOperationFactoryProtocol? {
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let statusService = ExtrinsicStatusService(
            connection: connection,
            runtimeProvider: runtimeProvider,
            eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
            logger: Logger.shared
        )

        let extrinsicService = extrinsicServiceFactory.createService(
            account: account.chainAccount,
            chain: state.stakingOption.chainAsset.chain
        )

        return try? state.createSubmissionOperationFactory(
            for: account.chainAccount.accountId,
            extrinsicService: extrinsicService,
            extrinsicSubmitMonitor: ExtrinsicSubmissionMonitorFactory(
                submissionService: extrinsicService,
                statusService: statusService,
                operationQueue: operationQueue
            ),
            signer: createSigner(for: account),
            shield: createShieldServices(
                for: account,
                state: state,
                connection: connection,
                runtimeProvider: runtimeProvider,
                extrinsicServiceFactory: extrinsicServiceFactory,
                statusService: statusService,
                operationQueue: operationQueue
            )
        )
    }

    // swiftlint:disable:next function_parameter_count
    static func createShieldServices(
        for account: MetaChainAccountResponse,
        state: SubtensorSharedStateProtocol,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorShieldServices? {
        guard SubtensorShieldEligibility.supports(walletType: account.chainAccount.type) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset

        let submissionOperationFactory = SubtensorShieldSubmissionOperationFactory(
            walletType: account.chainAccount.type,
            extrinsicOperationFactory: SubtensorShieldExtrinsicOperationFactory(
                account: account.chainAccount,
                chain: chainAsset.chain,
                connection: connection,
                extrinsicServiceFactory: extrinsicServiceFactory,
                keyOperationFactory: MevShieldOperationFactory(
                    runtimeProvider: runtimeProvider,
                    connection: connection,
                    operationQueue: operationQueue
                ),
                sealer: MevShieldSealer(),
                operationQueue: operationQueue
            ),
            fundsOperationFactory: createShieldFundsOperationFactory(
                for: account.chainAccount.accountId,
                chainAsset: chainAsset,
                chainRegistry: state.chainRegistry,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            ),
            carrierWatch: SubtensorShieldCarrierWatch(connection: connection),
            inclusionOperationFactory: SubtensorShieldInclusionOperationFactory(
                connection: connection,
                statusService: statusService,
                operationQueue: operationQueue
            ),
            signerFactory: {
                SigningWrapperFactory().createAuthorizeOnceSigningWrapper(
                    for: account.metaId,
                    accountResponse: account.chainAccount,
                    signaturesPerAuthorization: SubtensorShieldConstants.signaturesPerOrder
                )
            },
            operationQueue: operationQueue
        )

        return SubtensorShieldServices(
            submissionOperationFactory: submissionOperationFactory,
            operationQueue: operationQueue
        )
    }

    static func createShieldFundsOperationFactory(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorShieldFundsOperationFactory {
        SubtensorShieldFundsOperationFactory(
            accountId: accountId,
            chainAsset: chainAsset,
            balanceQueryFactory: WalletRemoteQueryWrapperFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            runtimeProvider: runtimeProvider
        )
    }

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
