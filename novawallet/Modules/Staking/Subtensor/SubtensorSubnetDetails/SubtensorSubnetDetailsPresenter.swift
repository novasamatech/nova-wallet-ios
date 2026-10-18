import Foundation
import Foundation_iOS

final class SubtensorSubnetDetailsPresenter {
    weak var view: SubtensorSubnetDetailsViewProtocol?
    weak var selectionDelegate: SubtensorSubnetSelectDelegate?

    let input: SubtensorSubnetDetailsInput
    let host: SubtensorSubnetDetailsHost
    let interactor: SubnetDetailsInteractorInputProtocol
    let wireframe: SubtensorSubnetDetailsWireframeProtocol
    let viewModelFactory: SubnetDetailsViewModelFactoryProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let logger: LoggerProtocol

    private var isFiat = false
    private var period = SubtensorPriceWidgetViewModelFactory.defaultPeriod
    private var chartPoint: Int?
    private var history: SubtensorSubnetHistoryState = .loading {
        didSet {
            chartPoint = nil
        }
    }

    private var listing: SubtensorSubnetListingState = .loading
    private var isRankingLoaded = false
    private var rankingView: SubtensorRankedSubnets?
    private var hasExpiredRankingSeed = false
    private var validator: SubtensorSubnetValidatorState
    private var yields: SubtensorAlphaYields?
    private var amount = SubtensorSubnetDetailsViewModelFactory.defaultChip
    private var transferable: Balance?
    private var taoPrice: PriceData?
    private var subnetLogos: SubtensorSubnetLogos?
    private var positions: Multistaking.SubtensorStakingState?
    private var isPositionsSyncFailed = false
    private var isPresetRequested = false
    private var isUsePending = false

    init(
        input: SubtensorSubnetDetailsInput,
        host: SubtensorSubnetDetailsHost,
        selectionDelegate: SubtensorSubnetSelectDelegate,
        interactor: SubnetDetailsInteractorInputProtocol,
        wireframe: SubtensorSubnetDetailsWireframeProtocol,
        viewModelFactory: SubnetDetailsViewModelFactoryProtocol,
        earnSettings: SubtensorEarnSettingsProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.input = input
        self.host = host
        self.selectionDelegate = selectionDelegate
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.earnSettings = earnSettings
        self.logger = logger

        if let validator = input.validator {
            self.validator = .selected(validator)
        } else {
            validator = host == .picker ? .pending : .unselected
        }

        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetDetailsPresenter {
    var subnetRef: SubtensorSubnetRef {
        input.subnet.ref
    }

    var isFavorite: Bool {
        earnSettings.favouriteSubnets.contains(subnetRef)
    }

    var isUseEnabled: Bool {
        validator != .pending
    }

    func createState() -> SubtensorSubnetDetailsState {
        SubtensorSubnetDetailsState(
            isFiat: isFiat,
            period: period,
            history: history,
            listing: listing,
            isRankingLoaded: isRankingLoaded,
            rankingView: rankingView,
            validator: validator,
            yields: yields,
            amount: amount,
            transferable: transferable,
            taoPrice: taoPrice,
            isFavorite: isFavorite,
            now: Date(),
            chartPoint: chartPoint
        )
    }

    func provideTitle() {
        view?.didReceive(title: viewModelFactory.createTitle(subnetLogos: subnetLogos, locale: selectedLocale))
    }

    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            for: createState(),
            isUseEnabled: isUseEnabled,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    func seed(from snapshot: SubtensorSubnetDetailsSnapshot) {
        if let rankingView = snapshot.rankingView.value {
            self.rankingView = rankingView
            isRankingLoaded = true
            hasExpiredRankingSeed = !snapshot.rankingView.isFresh
        }

        if let yields = snapshot.yields.value {
            self.yields = yields
        }
    }

    func loadHistory() {
        history = .loading
        interactor.loadHistory(for: period)
    }

    func existingPrimaryHotkey() -> AccountId? {
        guard let positions else {
            return nil
        }

        let portfolio = SubtensorPortfolioBuilder.build(state: positions)

        return portfolio.subnets.first { $0.netuid == subnetRef.netuid }?.primaryHotkey
    }

    func requestPresetIfReady() {
        guard
            validator == .pending,
            !isPresetRequested,
            positions != nil || isPositionsSyncFailed else {
            return
        }

        isPresetRequested = true

        interactor.presetValidator(existingHotkey: existingPrimaryHotkey())
    }

    func complete(with validator: SubtensorValidatorDirectoryItem) {
        wireframe.complete(
            from: view,
            host: host,
            target: input.target,
            validator: validator,
            delegate: selectionDelegate
        )
    }

    func showValidators(completesOnSelection: Bool) {
        isUsePending = completesOnSelection

        wireframe.showValidators(
            from: view,
            target: input.target,
            selectedHotkey: validator.item?.hotkey,
            delegate: self
        )
    }
}

extension SubtensorSubnetDetailsPresenter: SubtensorSubnetDetailsPresenterProtocol {
    func setup() {
        seed(from: interactor.cachedSnapshot())

        provideTitle()
        provideViewModel()

        interactor.setup()
        interactor.loadHistory(for: period)
    }

    func selectCurrency(at index: Int) {
        let newIsFiat = index > 0

        guard newIsFiat != isFiat, !newIsFiat || taoPrice != nil else {
            provideViewModel()
            return
        }

        isFiat = newIsFiat
        provideViewModel()
    }

    func selectPeriod(at index: Int) {
        let periods = SubtensorPriceWidgetViewModelFactory.periods

        guard periods.indices.contains(index), periods[index] != period, history != .notListed else {
            provideViewModel()
            return
        }

        period = periods[index]
        loadHistory()
        provideViewModel()
    }

    func selectAmount(at index: Int) {
        let amounts = SubtensorSubnetDetailsViewModelFactory.chipAmounts

        if amounts.indices.contains(index) {
            amount = .fixed(amounts[index])
        } else if SubtensorSubnetDetailsViewModelFactory.maxAmount(for: transferable) != nil {
            amount = .max
        }

        provideViewModel()
    }

    func toggleFavorite() {
        var favorites = Set(earnSettings.favouriteSubnets)

        if !favorites.insert(subnetRef).inserted {
            favorites.remove(subnetRef)
        }

        earnSettings.favouriteSubnets = favorites.sorted { $0.netuid < $1.netuid }

        provideViewModel()
    }

    func selectValidator() {
        showValidators(completesOnSelection: false)
    }

    func useSubnet() {
        switch validator {
        case .pending:
            return
        case let .selected(item):
            complete(with: item)
        case .unselected:
            showValidators(completesOnSelection: true)
        }
    }

    func retryHistory() {
        guard history == .failed else {
            return
        }

        loadHistory()
        provideViewModel()
    }

    func selectChartPoint(at index: Int?) {
        chartPoint = index

        let header = viewModelFactory.createPriceHeader(for: createState(), locale: selectedLocale)
        view?.didReceive(priceHeader: header)
    }
}

extension SubtensorSubnetDetailsPresenter: SubnetDetailsInteractorOutputProtocol {
    func didReceiveHistory(_ result: SubtensorPriceHistoryResult, for period: SubtensorPricePeriod) {
        guard period == self.period else {
            return
        }

        switch result {
        case let .available(value):
            history = .available(value)
        case .notListed:
            history = .notListed
        }

        provideViewModel()
    }

    func didFailHistory(for period: SubtensorPricePeriod) {
        guard period == self.period else {
            return
        }

        history = .failed
        provideViewModel()
    }

    func didReceiveListing(_ result: SubtensorPriceHistoryResult?) {
        switch result {
        case let .available(value):
            listing = .listed(since: value.points.first?.date)
        case .notListed:
            listing = .notListed
        case .none:
            listing = .failed
        }

        provideViewModel()
    }

    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?) {
        guard rankingView != nil || !hasExpiredRankingSeed else {
            return
        }

        self.rankingView = rankingView
        isRankingLoaded = true
        provideViewModel()
    }

    func didReceivePreset(_ validator: SubtensorValidatorDirectoryItem?) {
        guard self.validator == .pending else {
            return
        }

        self.validator = validator.map { .selected($0) } ?? .unselected
        provideViewModel()
    }

    func didReceiveYields(_ yields: SubtensorAlphaYields?) {
        self.yields = yields
        provideViewModel()
    }

    func didReceiveBalance(_ balance: AssetBalance?) {
        transferable = balance?.transferable

        if amount == .max, SubtensorSubnetDetailsViewModelFactory.maxAmount(for: transferable) == nil {
            amount = SubtensorSubnetDetailsViewModelFactory.defaultChip
        }

        provideViewModel()
    }

    func didReceiveTaoPrice(_ price: PriceData?) {
        taoPrice = price
        provideViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        positions = state
        requestPresetIfReady()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed
        requestPresetIfReady()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?) {
        subnetLogos = logos
        provideTitle()
    }
}

extension SubtensorSubnetDetailsPresenter: SubtensorValidatorSelectDelegate {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for _: SubtensorStakeTarget) {
        self.validator = .selected(validator)
        provideViewModel()

        guard isUsePending else {
            return
        }

        isUsePending = false
        complete(with: validator)
    }
}

extension SubtensorSubnetDetailsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideTitle()
            provideViewModel()
        }
    }
}
