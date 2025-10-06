import UIKit
import Operation_iOS
import BigInt

class CrowdloanContributionInteractor: CrowdloanContributionInteractorInputProtocol, RuntimeConstantFetching {
    weak var presenter: CrowdloanContributionInteractorOutputProtocol!

    let paraId: ParaId
    let selectedMetaAccount: MetaAccountModel
    let chain: ChainModel
    let asset: AssetModel
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var crowdloanProvider: AnyDataProvider<DecodedCrowdloanFunds>?
    private var displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>?

    private(set) lazy var callFactory = SubstrateCallFactory()

    init(
        paraId: ParaId,
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.paraId = paraId
        self.selectedMetaAccount = selectedMetaAccount
        self.chain = chain
        self.asset = asset
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.crowdloanLocalSubscriptionFactory = crowdloanLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.jsonLocalSubscriptionFactory = jsonLocalSubscriptionFactory

        self.operationManager = operationManager
        self.currencyManager = currencyManager
    }

    private func provideConstants() {
        fetchConstant(
            for: BabePallet.blockTimePath,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.presenter.didReceiveBlockDuration(result: result)
        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            self?.presenter.didReceiveLeasingPeriod(result: result)
        }

        fetchConstant(
            for: .paraLeasingOffset,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingOffset, Error>) in
            self?.presenter.didReceiveLeasingOffset(result: result)
        }

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveMinimumBalance(result: result)
        }

        fetchConstant(
            for: .minimumContribution,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveMinimumContribution(result: result)
        }
    }

    private func subscribeToDisplayInfo() {
        if let displayInfoUrl = chain.externalApis?.crowdloans()?.first?.url {
            displayInfoProvider = subscribeToCrowdloanDisplayInfo(
                for: displayInfoUrl,
                chainId: chain.chainId
            )
        } else {
            presenter.didReceiveDisplayInfo(result: .success(nil))
        }
    }

    private func subscribeToCrowdloanFunds() {
        crowdloanProvider = subscribeToCrowdloanFunds(for: paraId, chainId: chain.chainId)
    }

    private func subscribeToAccountInfo() {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            presenter.didReceiveAccountBalance(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func subscribeToPrice() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }
    }

    func setup() {
        feeProxy.delegate = self

        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)

        subscribeToPrice()
        subscribeToAccountInfo()
        subscribeToDisplayInfo()
        subscribeToCrowdloanFunds()

        provideConstants()
    }

    func estimateFee(for amount: BigUInt, bonusService: CrowdloanBonusServiceProtocol?) {
        let call = callFactory.contribute(to: paraId, amount: amount, signature: nil)

        let identifier = String(amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            let nextBuilder = try builder.adding(call: call)
            return try bonusService?.applyOnchainBonusForContribution(
                amount: amount,
                using: nextBuilder
            ) ?? nextBuilder
        }
    }
}

extension CrowdloanContributionInteractor: CrowdloanLocalStorageSubscriber,
    CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveBlockNumber(result: result)
    }

    func handleCrowdloanFunds(
        result: Result<CrowdloanFunds?, Error>,
        for paraId: ParaId,
        chainId _: ChainModel.Id
    ) {
        do {
            if let crowdloanFunds = try result.get() {
                let crowdloan = Crowdloan(paraId: paraId, fundInfo: crowdloanFunds)
                presenter.didReceiveCrowdloan(result: .success(crowdloan))
            }
        } catch {
            presenter.didReceiveCrowdloan(result: .failure(error))
        }
    }
}

extension CrowdloanContributionInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension CrowdloanContributionInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension CrowdloanContributionInteractor: JsonLocalStorageSubscriber, JsonLocalSubscriptionHandler {
    func handleCrowdloanDisplayInfo(
        result: Result<CrowdloanDisplayInfoList?, Error>,
        url _: URL,
        chainId _: ChainModel.Id
    ) {
        do {
            if let result = try result.get() {
                let displayInfoDict = result.toMap()
                let displayInfo = displayInfoDict[paraId]
                presenter.didReceiveDisplayInfo(result: .success(displayInfo))
            } else {
                presenter.didReceiveDisplayInfo(result: .success(nil))
            }
        } catch {
            presenter.didReceiveDisplayInfo(result: .failure(error))
        }
    }
}

extension CrowdloanContributionInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension CrowdloanContributionInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, let priceId = asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
