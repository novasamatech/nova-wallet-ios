import Foundation
import SoraFoundation
import BigInt
import RobinHood

class AssetSelectionBasePresenter {
    weak var view: AssetSelectionViewProtocol?
    let baseWireframe: AssetSelectionBaseWireframeProtocol
    let interactor: AssetSelectionInteractorInputProtocol

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private(set) var assets: [ChainAsset]?

    private var accountBalances: [ChainAssetId: Result<BigUInt?, Error>]?
    private var assetPrices: [ChainAssetId: PriceData]?

    private var viewModels: [SelectableIconDetailsListViewModel] = []

    var isReadyForDisplay: Bool {
        assets != nil && accountBalances != nil && assetPrices != nil
    }

    init(
        interactor: AssetSelectionInteractorInputProtocol,
        baseWireframe: AssetSelectionBaseWireframeProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.baseWireframe = baseWireframe
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.localizationManager = localizationManager
    }

    private func extractAvailableBalanceInPlank(for chainAsset: ChainAsset) -> BigUInt? {
        guard
            let balanceResult = accountBalances?[chainAsset.chainAssetId],
            case let .success(balance) = balanceResult else {
            return nil
        }

        return balance ?? 0
    }

    private func extractFiatBalance(for chainAsset: ChainAsset) -> Decimal? {
        guard
            let balanceResult = accountBalances?[chainAsset.chainAssetId],
            case let .success(balance) = balanceResult,
            let priceString = assetPrices?[chainAsset.chainAssetId]?.price,
            let price = Decimal(string: priceString),
            let balanceDecimal = Decimal.fromSubstrateAmount(
                balance ?? 0,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return nil
        }

        return balanceDecimal * price
    }

    func extractFormattedBalance(for chainAsset: ChainAsset) -> String? {
        let assetInfo = chainAsset.assetDisplayInfo

        let maybeBalance: Decimal?

        if let balanceInPlank = extractAvailableBalanceInPlank(for: chainAsset) {
            maybeBalance = Decimal.fromSubstrateAmount(
                balanceInPlank,
                precision: assetInfo.assetPrecision
            )
        } else {
            maybeBalance = 0.0
        }

        guard let balance = maybeBalance else {
            return nil
        }

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetInfo)
            .value(for: selectedLocale)

        return tokenFormatter.stringFromDecimal(balance)
    }

    private func updateSorting() {
        assets?.sort { chainAsset1, chainAsset2 in
            let balance1 = extractAvailableBalanceInPlank(for: chainAsset1) ?? 0
            let balance2 = extractAvailableBalanceInPlank(for: chainAsset2) ?? 0

            let assetValue1 = extractFiatBalance(for: chainAsset1) ?? 0
            let assetValue2 = extractFiatBalance(for: chainAsset2) ?? 0

            let priorityAndTestnetResult = ChainModelCompator.priorityAndTestnetComparator(
                chain1: chainAsset1.chain,
                chain2: chainAsset2.chain
            )

            if priorityAndTestnetResult != .orderedSame {
                return priorityAndTestnetResult == .orderedAscending
            } else if assetValue1 > 0, assetValue2 > 0 {
                return assetValue1 > assetValue2
            } else if assetValue1 > 0 {
                return true
            } else if assetValue2 > 0 {
                return false
            } else if balance1 > 0, balance2 > 0 {
                return balance1 > balance2
            } else if balance1 > 0 {
                return true
            } else if balance2 > 0 {
                return false
            } else {
                return chainAsset1.chain.name.lexicographicallyPrecedes(chainAsset2.chain.name)
            }
        }
    }

    func updateViewModels(_ viewModels: [SelectableIconDetailsListViewModel]) {
        self.viewModels = viewModels
    }

    func updateView() {
        fatalError("Child presenter must override this method")
    }

    func handleAssetSelection(at _: Int) {
        fatalError("Child presenter must override this method")
    }
}

extension AssetSelectionBasePresenter: AssetSelectionPresenterProtocol {
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        handleAssetSelection(at: index)
    }

    func setup() {
        interactor.setup()
    }
}

extension AssetSelectionBasePresenter: AssetSelectionInteractorOutputProtocol {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            assets = chainAssets

            updateSorting()
            updateView()
        case let .failure(error):
            _ = baseWireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>]) {
        if accountBalances == nil {
            accountBalances = [:]
        }

        results.forEach { key, result in
            switch result {
            case let .success(maybeAmount):
                if let amount = maybeAmount {
                    accountBalances?[key] = .success(amount)
                } else if accountBalances?[key] == nil {
                    accountBalances?[key] = .success(0)
                }
            case let .failure(error):
                accountBalances?[key] = .failure(error)
            }
        }

        updateSorting()
        updateView()
    }

    func didReceivePrice(changes: [ChainAssetId: DataProviderChange<PriceData>]) {
        assetPrices = changes.reduce(into: assetPrices ?? [:]) { accum, keyValue in
            accum[keyValue.key] = keyValue.value.item
        }

        updateSorting()
        updateView()
    }

    func didReceivePrice(error _: Error) {
        // ignore error because price only needed for sorting
    }
}

extension AssetSelectionBasePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
