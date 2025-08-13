import UIKit
import Keystore_iOS
import Operation_iOS
import BigInt
import SubstrateSdk
import NovaCrypto

final class StakingRedeemInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let slashesOperationFactory: SlashesOperationFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationManager: OperationManagerProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        operationManager: OperationManagerProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.accountRepositoryFactory = accountRepositoryFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.slashesOperationFactory = slashesOperationFactory
        self.feeProxy = feeProxy
        self.operationManager = operationManager
        self.currencyManager = currencyManager
    }

    private func handleControllerMetaAccount(response: MetaChainAccountResponse) {
        let chain = chainAsset.chain

        extrinsicService = extrinsicServiceFactory.createService(
            account: response.chainAccount,
            chain: chain
        )

        signingWrapper = signingWrapperFactory.createSigningWrapper(
            for: response.metaId,
            accountResponse: response.chainAccount
        )
    }

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        numberOfSlashingSpans: UInt32
    ) throws -> ExtrinsicBuilderProtocol {
        try builder.adding(call: callFactory.withdrawUnbonded(for: numberOfSlashingSpans))
    }

    private func fetchSlashingSpansForStash(
        _ stash: AccountAddress,
        completionClosure: @escaping (Result<Staking.SlashingSpans?, Error>) -> Void
    ) {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            completionClosure(.failure(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let registryService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            completionClosure(.failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let wrapper = slashesOperationFactory.createSlashingSpansOperationForStash(
            { try stash.toAccountId() },
            engine: connection,
            runtimeService: registryService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(
            operations: wrapper.allOperations,
            in: .transient
        )
    }

    private func estimateFee(with numberOfSlasingSpans: UInt32) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let reuseIdentifier = numberOfSlasingSpans.description

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier
        ) { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                numberOfSlashingSpans: numberOfSlasingSpans
            )
        }
    }

    private func submit(with numberOfSlasingSpans: UInt32) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper else {
            presenter.didSubmitRedeeming(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            { [weak self] builder in
                guard let strongSelf = self else {
                    throw CommonError.undefined
                }

                return try strongSelf.setupExtrinsicBuiler(
                    builder,
                    numberOfSlashingSpans: numberOfSlasingSpans
                )
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitRedeeming(result: result)
            }
        )
    }
}

extension StakingRedeemInteractor: StakingRedeemInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
        } else {
            presenter.didReceiveStashItem(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        if let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) {
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<BigUInt, Error>) in
                self?.presenter.didReceiveExistentialDeposit(result: result)
            }
        } else {
            presenter.didReceiveExistentialDeposit(
                result: .failure(ChainRegistryError.runtimeMetadaUnavailable)
            )
        }

        feeProxy.delegate = self
    }

    func estimateFeeForStash(_ stashAddress: AccountAddress) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans?.numOfSlashingSpans ?? 0
                self?.estimateFee(with: numberOfSlashes)
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }

    func submitForStash(_ stashAddress: AccountAddress) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans?.numOfSlashingSpans ?? 0
                self?.submit(with: numberOfSlashes)
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }
}

extension StakingRedeemInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(streamableProvider: &balanceProvider)
            clear(dataProvider: &ledgerProvider)

            let maybeStashItem = try result.get()
            let maybeControllerId = try maybeStashItem.map { try $0.controller.toAccountId() }

            presenter.didReceiveStashItem(result: result)

            if let controllerId = maybeControllerId {
                ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainAsset.chain.chainId)

                balanceProvider = subscribeToAssetBalanceProvider(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )

                fetchFirstMetaAccountResponse(
                    for: controllerId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(maybeResponse):
                        if let response = maybeResponse {
                            self?.handleControllerMetaAccount(response: response)
                        }

                        self?.presenter.didReceiveController(result: .success(maybeResponse))
                    case let .failure(error):
                        self?.presenter.didReceiveController(result: .failure(error))
                    }
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountBalance(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountBalance(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<Staking.ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveActiveEra(result: result)
    }
}

extension StakingRedeemInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension StakingRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRedeemInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension StakingRedeemInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
