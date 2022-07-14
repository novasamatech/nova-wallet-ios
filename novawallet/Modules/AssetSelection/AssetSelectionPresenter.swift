import Foundation
import SoraFoundation
import BigInt

final class AssetSelectionPresenter {
    weak var view: AssetSelectionViewProtocol?
    let wireframe: AssetSelectionWireframeProtocol
    let interactor: AssetSelectionInteractorInputProtocol
    let selectedChainAssetId: ChainAssetId?

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private var assets: [ChainAsset] = []

    private var accountBalances: [ChainAssetId: Result<BigUInt?, Error>] = [:]
    private var assetPrices: [ChainAssetId: PriceData] = [:]

    private var viewModels: [SelectableIconDetailsListViewModel] = []

    init(
        interactor: AssetSelectionInteractorInputProtocol,
        wireframe: AssetSelectionWireframeProtocol,
        selectedChainAssetId: ChainAssetId?,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedChainAssetId = selectedChainAssetId
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.localizationManager = localizationManager
    }

    private func extractAvailableBalanceInPlank(for chainAsset: ChainAsset) -> BigUInt? {
        guard
            let balanceResult = accountBalances[chainAsset.chainAssetId],
            case let .success(balance) = balanceResult else {
            return nil
        }

        return balance ?? 0
    }

    private func extractFiatBalance(for chainAsset: ChainAsset) -> Decimal? {
        guard
            let balanceResult = accountBalances[chainAsset.chainAssetId],
            case let .success(balance) = balanceResult,
            let priceString = assetPrices[chainAsset.chainAssetId]?.price,
            let price = Decimal(string: priceString),
            let balanceDecimal = Decimal.fromSubstrateAmount(
                balance ?? 0,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return nil
        }

        return balanceDecimal * price
    }

    private func extractFormattedBalance(for chainAsset: ChainAsset) -> String? {
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
        assets.sort { chainAsset1, chainAsset2 in
            let balance1 = extractAvailableBalanceInPlank(for: chainAsset1) ?? 0
            let balance2 = extractAvailableBalanceInPlank(for: chainAsset2) ?? 0

            let assetValue1 = extractFiatBalance(for: chainAsset1) ?? 0
            let assetValue2 = extractFiatBalance(for: chainAsset2) ?? 0

            let priorityAndTestnetResult = ChainModelCompator.priorityAndTestnetComparator(
                chain1: chainAsset1.chain,
                chain2: chainAsset2.chain
            )

            if priorityAndTestnetResult != .orderedSame {
                return priorityAndTestnetResult == .orderedAscending ? true : false
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

    private func updateView() {
        viewModels = assets.compactMap { chainAsset in
            let chain = chainAsset.chain
            let asset = chainAsset.asset

            let icon = RemoteImageViewModel(url: asset.icon ?? chain.icon)
            let title = asset.name ?? chain.name
            let isSelected = selectedChainAssetId?.assetId == asset.assetId &&
                selectedChainAssetId?.chainId == chain.chainId
            let balance = extractFormattedBalance(for: chainAsset) ?? ""

            return SelectableIconDetailsListViewModel(
                title: title,
                subtitle: balance,
                icon: icon,
                isSelected: isSelected
            )
        }

        view?.didReload()
    }
}

extension AssetSelectionPresenter: AssetSelectionPresenterProtocol {
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        guard let view = view else {
            return
        }

        wireframe.complete(on: view, selecting: assets[index])
    }

    func setup() {
        interactor.setup()
    }
}

extension AssetSelectionPresenter: AssetSelectionInteractorOutputProtocol {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            assets = chainAssets

            updateSorting()
            updateView()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>]) {
        results.forEach { key, value in
            accountBalances[key] = value
        }

        updateSorting()
        updateView()
    }

    func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?) {
        switch result {
        case let .success(prices):
            assetPrices = prices

            updateSorting()
            updateView()
        case .failure, .none:
            // ignore any price errors as it is needed only for sorting
            break
        }
    }
}

extension AssetSelectionPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
