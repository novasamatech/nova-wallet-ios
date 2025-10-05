import UIKit
import Operation_iOS

final class CrowdloanYourContributionsInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanYourContributionsInteractorOutputProtocol?

    let chain: ChainModel
    let selectedMetaAccount: MetaAccountModel
    let operationQueue: OperationQueue
    let crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeProviderProtocol

    private var externalContributionsProvider: AnySingleValueProvider<[ExternalContribution]>?

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        operationQueue: OperationQueue,
        runtimeService: RuntimeProviderProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
        self.operationQueue = operationQueue
        self.runtimeService = runtimeService
        self.crowdloanOffchainProviderFactory = crowdloanOffchainProviderFactory
        self.crowdloanLocalSubscriptionFactory = crowdloanLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func subscribeBlockNumber() {
        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
    }

    private func subscribeExternalContributions() {
        if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
            externalContributionsProvider = subscribeToExternalContributionsProvider(
                for: accountId,
                chain: chain
            )
        } else {
            presenter?.didReceiveError(ChainAccountFetchingError.accountNotExists)
        }
    }

    private func subscribePrice() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
        }
    }

    private func provideConstants() {
        fetchConstant(
            for: BabePallet.blockTimePath,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BlockTime, Error>) in
            switch result {
            case let .success(blockTime):
                self?.presenter?.didReceiveBlockDuration(blockTime)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            switch result {
            case let .success(period):
                self?.presenter?.didReceiveLeasingPeriod(period)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }

        fetchConstant(
            for: .paraLeasingOffset,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<LeasingOffset, Error>) in
            switch result {
            case let .success(offset):
                self?.presenter?.didReceiveLeasingOffset(offset)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanLocalStorageSubscriber,
    CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            presenter?.didReceiveBlockNumber(blockNumber)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanYourContributionsInteractorInputProtocol {
    func setup() {
        subscribeExternalContributions()
        subscribeBlockNumber()
        subscribePrice()
        provideConstants()
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanOffchainSubscriber, CrowdloanOffchainSubscriptionHandler {
    func handleExternalContributions(
        result: Result<[ExternalContribution]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(maybeContributions):
            presenter?.didReceiveExternalContributions(maybeContributions ?? [])
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanYourContributionsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanYourContributionsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}
