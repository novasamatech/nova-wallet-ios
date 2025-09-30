import UIKit
import Keystore_iOS
import Operation_iOS
import BigInt
import SubstrateSdk
import NovaCrypto

final class StakingRebondConfirmationInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondConfirmationInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationManager: OperationManagerProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        operationManager: OperationManagerProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.accountRepositoryFactory = accountRepositoryFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
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
}

extension StakingRebondConfirmationInteractor: StakingRebondConfirmationInteractorInputProtocol {
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

        feeProxy.delegate = self
    }

    func submit(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let signingWrapper = signingWrapper,
              let amountValue = amount.toSubstrateAmount(
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
            presenter.didSubmitRebonding(result: .failure(CommonError.undefined))
            return
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: rebondCall)
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitRebonding(result: result)
            }
        )
    }

    func estimateFee(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let amountValue = amount.toSubstrateAmount(
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: rebondCall.callName) { builder in
            try builder.adding(call: rebondCall)
        }
    }
}

extension StakingRebondConfirmationInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
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
}

extension StakingRebondConfirmationInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension StakingRebondConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRebondConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension StakingRebondConfirmationInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
