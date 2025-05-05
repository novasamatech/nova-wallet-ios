import Foundation
import Foundation_iOS
import BigInt
import Operation_iOS

class ChainAssetSelectionBasePresenter {
    weak var view: ChainAssetSelectionViewProtocol?
    let baseWireframe: ChainAssetSelectionBaseWireframeProtocol
    let interactor: ChainAssetSelectionInteractorInputProtocol

    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    var assets: [ChainAsset]?

    private var accountBalances: [ChainAssetId: AssetBalance]?
    private var assetPrices: [ChainAssetId: PriceData]?

    private var viewModels: [SelectableIconDetailsListViewModel] = []

    var isReadyForDisplay: Bool {
        assets != nil && accountBalances != nil && assetPrices != nil
    }

    init(
        interactor: ChainAssetSelectionInteractorInputProtocol,
        baseWireframe: ChainAssetSelectionBaseWireframeProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.baseWireframe = baseWireframe
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.localizationManager = localizationManager
    }

    func extractAvailableBalanceInPlank(
        for chainAsset: ChainAsset,
        balanceMapper: AvailableBalanceMapping
    ) -> BigUInt {
        let balance = accountBalances?[chainAsset.chainAssetId]
        return balanceMapper.availableBalanceElseZero(from: balance)
    }

    func extractFiatBalance(for chainAsset: ChainAsset, balanceMapper: AvailableBalanceMapping) -> Decimal? {
        guard
            let priceString = assetPrices?[chainAsset.chainAssetId]?.price,
            let price = Decimal(string: priceString) else {
            return nil
        }

        let availableBalance = extractAvailableBalanceInPlank(
            for: chainAsset,
            balanceMapper: balanceMapper
        )

        let balanceDecimal = availableBalance.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceDecimal * price
    }

    func extractFormattedBalance(
        for chainAsset: ChainAsset,
        balanceMapper: AvailableBalanceMapping
    ) -> String? {
        let assetInfo = chainAsset.assetDisplayInfo

        let balanceInPlank = extractAvailableBalanceInPlank(
            for: chainAsset,
            balanceMapper: balanceMapper
        )

        let balanceDecimal = balanceInPlank.decimal(assetInfo: assetInfo)

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetInfo)
            .value(for: selectedLocale)

        return tokenFormatter.stringFromDecimal(balanceDecimal)
    }

    func orderAssets(
        _ chainAsset1: ChainAsset,
        chainAsset2: ChainAsset,
        balanceMapper: AvailableBalanceMapping
    ) -> Bool {
        let balance1 = extractAvailableBalanceInPlank(
            for: chainAsset1,
            balanceMapper: balanceMapper
        )

        let balance2 = extractAvailableBalanceInPlank(
            for: chainAsset2,
            balanceMapper: balanceMapper
        )

        let assetValue1 = extractFiatBalance(
            for: chainAsset1,
            balanceMapper: balanceMapper
        ) ?? 0

        let assetValue2 = extractFiatBalance(
            for: chainAsset2,
            balanceMapper: balanceMapper
        ) ?? 0

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

    func updateAvailableOptions() {
        fatalError("Child presenter must override this method")
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

extension ChainAssetSelectionBasePresenter: ChainAssetSelectionPresenterProtocol {
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

extension ChainAssetSelectionBasePresenter: ChainAssetSelectionInteractorOutputProtocol {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            assets = chainAssets

            updateAvailableOptions()
            updateView()
        case let .failure(error):
            _ = baseWireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveBalance(resultWithChanges: Result<[ChainAssetId: AssetBalance], Error>) {
        switch resultWithChanges {
        case let .success(changes):
            if accountBalances == nil {
                accountBalances = [:]
            }

            changes.forEach { keyValue in
                accountBalances?[keyValue.key] = keyValue.value
            }

            updateAvailableOptions()
            updateView()
        case let .failure(error):
            _ = baseWireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceivePrice(changes: [ChainAssetId: DataProviderChange<PriceData>]) {
        assetPrices = changes.reduce(into: assetPrices ?? [:]) { accum, keyValue in
            accum[keyValue.key] = keyValue.value.item
        }

        updateAvailableOptions()
        updateView()
    }

    func didReceivePrice(error _: Error) {
        // ignore error because price only needed for sorting
    }
}

extension ChainAssetSelectionBasePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
