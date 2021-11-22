import UIKit
import SoraKeystore
import RobinHood
import BigInt
import SubstrateSdk
import IrohaCrypto

final class StakingRedeemInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let slashesOperationFactory: SlashesOperationFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationManager: OperationManagerProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.accountRepositoryFactory = accountRepositoryFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.slashesOperationFactory = slashesOperationFactory
        self.feeProxy = feeProxy
        self.operationManager = operationManager
    }

    private func handleControllerMetaAccount(response: MetaChainAccountResponse) {
        extrinsicService = extrinsicServiceFactory.createService(
            accountId: response.chainAccount.accountId,
            chainFormat: response.chainAccount.chainFormat,
            cryptoType: response.chainAccount.cryptoType
        )

        signingWrapper = extrinsicServiceFactory.createSigningWrapper(
            metaId: response.metaId,
            account: response.chainAccount
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
        completionClosure: @escaping (Result<SlashingSpans?, Error>) -> Void
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
            stash,
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
            stashItemProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveStashItem(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
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
                let numberOfSlashes = slashingSpans.map { $0.prior.count + 1 } ?? 0
                self?.estimateFee(with: UInt32(numberOfSlashes))
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }

    func submitForStash(_ stashAddress: AccountAddress) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans.map { $0.prior.count + 1 } ?? 0
                self?.submit(with: UInt32(numberOfSlashes))
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
            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            let maybeStashItem = try result.get()
            let maybeControllerId = try maybeStashItem.map { try $0.controller.toAccountId() }

            presenter.didReceiveStashItem(result: result)

            if let controllerId = maybeControllerId {
                ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainAsset.chain.chainId)

                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId
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

                        let accountItem = try? maybeResponse?.chainAccount.toAccountItem()
                        self?.presenter.didReceiveController(result: .success(accountItem))
                    case let .failure(error):
                        self?.presenter.didReceiveController(result: .failure(error))
                    }
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveActiveEra(result: result)
    }
}

extension StakingRedeemInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRedeemInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
