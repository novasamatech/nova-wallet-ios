import UIKit
import RobinHood

final class CrowdloanYourContributionsInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanYourContributionsInteractorOutputProtocol!

    let chain: ChainModel
    let selectedMetaAccount: MetaAccountModel
    let operationManager: OperationManagerProtocol
    let crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeProviderProtocol

    private var externalContributionsProvider: AnySingleValueProvider<[ExternalContribution]>?

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeProviderProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.crowdloanOffchainProviderFactory = crowdloanOffchainProviderFactory
        self.crowdloanLocalSubscriptionFactory = crowdloanLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
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
            presenter.didReceiveError(ChainAccountFetchingError.accountNotExists)
        }
    }

    private func subscribePrice() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePrice(nil)
        }
    }

    private func provideConstants() {
        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            switch result {
            case let .success(blockTime):
                self?.presenter.didReceiveBlockDuration(blockTime)
            case let .failure(error):
                self?.presenter.didReceiveError(error)
            }

        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            switch result {
            case let .success(period):
                self?.presenter.didReceiveLeasingPeriod(period)
            case let .failure(error):
                self?.presenter.didReceiveError(error)
            }
        }
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanLocalStorageSubscriber,
    CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            presenter.didReceiveBlockNumber(blockNumber)
        case let .failure(error):
            presenter.didReceiveError(error)
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
            presenter.didReceiveExternalContributions(maybeContributions ?? [])
        case let .failure(error):
            presenter.didReceiveError(error)
        }
    }
}

extension CrowdloanYourContributionsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter.didReceivePrice(priceData)
        case let .failure(error):
            presenter.didReceiveError(error)
        }
    }
}
