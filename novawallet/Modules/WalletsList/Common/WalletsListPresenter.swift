import Foundation
import RobinHood
import BigInt
import SoraFoundation

class WalletsListPresenter {
    weak var baseView: WalletsListViewProtocol?
    let baseWireframe: WalletsListWireframeProtocol
    let baseInteractor: WalletsListInteractorInputProtocol
    let viewModelFactory: WalletsListViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var viewModels: [WalletsListSectionViewModel] = []

    let walletsList: ListDifferenceCalculator<ManagedMetaAccountModel> = {
        let calculator = ListDifferenceCalculator<ManagedMetaAccountModel>(
            initialItems: []
        ) { item1, item2 in
            item1.order < item2.order
        }

        return calculator
    }()

    private var identifierMapping: [String: AssetBalanceId] = [:]
    private var balances: [AccountId: [ChainAssetId: BigUInt]] = [:]
    private var crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]] = [:]
    private var crowdloanContributionsMapping: [String: CrowdloanContributionId] = [:]
    private var prices: [ChainAssetId: PriceData] = [:]
    private var chains: [ChainModel.Id: ChainModel] = [:]

    init(
        baseInteractor: WalletsListInteractorInputProtocol,
        baseWireframe: WalletsListWireframeProtocol,
        viewModelFactory: WalletsListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.baseInteractor = baseInteractor
        self.baseWireframe = baseWireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func replaceViewModels(_ items: [WalletsListViewModel], section: Int) {
        let type = viewModels[section].type
        viewModels[section] = WalletsListSectionViewModel(type: type, items: items)
    }

    private func updateViewModels() {
        viewModels = viewModelFactory.createSectionViewModels(
            for: walletsList.allItems,
            chains: chains,
            balances: balances,
            crowdloanContributions: crowdloanContributions,
            prices: prices,
            locale: selectedLocale
        )

        baseView?.didReload()
    }
}

extension WalletsListPresenter: WalletsListPresenterProtocol {
    func setup() {
        baseInteractor.setup()
    }

    func numberOfSections() -> Int {
        viewModels.count
    }

    func numberOfItems(in section: Int) -> Int {
        viewModels[section].items.count
    }

    func item(at index: Int, in section: Int) -> WalletsListViewModel {
        viewModels[section].items[index]
    }

    func section(at index: Int) -> WalletsListSectionViewModel {
        viewModels[index]
    }
}

extension WalletsListPresenter: WalletsListInteractorOutputProtocol {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        walletsList.apply(changes: changes)

        updateViewModels()
    }

    func didReceiveBalancesChanges(_ changes: [DataProviderChange<AssetBalance>]) {
        for change in changes {
            switch change {
            case let .insert(item), let .update(item):
                var accountBalance = balances[item.accountId] ?? [:]
                accountBalance[item.chainAssetId] = item.totalInPlank
                balances[item.accountId] = accountBalance

                identifierMapping[item.identifier] = AssetBalanceId(
                    chainId: item.chainAssetId.chainId,
                    assetId: item.chainAssetId.assetId,
                    accountId: item.accountId
                )
            case let .delete(deletedIdentifier):
                if let accountBalanceId = identifierMapping[deletedIdentifier] {
                    var accountBalance = balances[accountBalanceId.accountId]
                    accountBalance?[accountBalanceId.chainAssetId] = nil
                    balances[accountBalanceId.accountId] = accountBalance
                }

                identifierMapping[deletedIdentifier] = nil
            }
        }

        updateViewModels()
    }

    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)

        updateViewModels()
    }

    func didReceivePrices(_ prices: [ChainAssetId: PriceData]) {
        self.prices = prices

        updateViewModels()
    }

    func didReceiveCrowdloanContributionChanges(_ changes: [DataProviderChange<CrowdloanContributionData>]) {
        for change in changes {
            switch change {
            case let .insert(item), let .update(item):
                var accountCrowdloan = crowdloanContributions[item.accountId] ?? [:]
                let value: BigUInt = accountCrowdloan[item.chainId] ?? 0
                accountCrowdloan[item.chainId] = value + item.amount
                crowdloanContributions[item.accountId] = accountCrowdloan
                crowdloanContributionsMapping[item.identifier] = CrowdloanContributionId(
                    chainId: item.chainId,
                    accountId: item.accountId,
                    amount: item.amount
                )
            case let .delete(deletedIdentifier):
                if let accountContributionId = crowdloanContributionsMapping[deletedIdentifier] {
                    var accountContributions = crowdloanContributions[accountContributionId.accountId]
                    if let contribution = accountContributions?[accountContributionId.chainId],
                       contribution > accountContributionId.amount {
                        let newAmount = contribution - accountContributionId.amount
                        accountContributions?[accountContributionId.chainId] = newAmount
                    } else {
                        accountContributions?[accountContributionId.chainId] = nil
                    }
                    crowdloanContributions[accountContributionId.accountId] = accountContributions
                }

                crowdloanContributionsMapping[deletedIdentifier] = nil
            }
        }

        updateViewModels()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        _ = baseWireframe.present(error: error, from: baseView, locale: selectedLocale)
    }
}

extension WalletsListPresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateViewModels()
        }
    }
}
