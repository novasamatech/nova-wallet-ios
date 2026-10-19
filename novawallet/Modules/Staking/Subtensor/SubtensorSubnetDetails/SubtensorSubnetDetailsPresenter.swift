import Foundation
import Foundation_iOS

final class SubtensorSubnetDetailsPresenter {
    weak var view: SubtensorSubnetDetailsViewProtocol?
    weak var selectionDelegate: SubtensorSubnetSelectDelegate?

    let input: SubtensorSubnetDetailsInput
    let host: SubtensorSubnetDetailsHost
    let interactor: SubtensorSubnetDetailsInteractorInputProtocol
    let wireframe: SubtensorSubnetDetailsWireframeProtocol
    let viewModelFactory: SubtensorSubnetDetailsViewModelFactoryProtocol

    private var state: SubtensorSubnetDetailsState
    private var subnetLogos: SubtensorSubnetLogos?
    private var positions: Multistaking.SubtensorState?
    private var registrationDate: Date?
    private var isPositionsSyncFailed = false
    private var isParametersRequested = false
    private var isPresetRequested = false
    private var isUsePending = false

    init(
        input: SubtensorSubnetDetailsInput,
        host: SubtensorSubnetDetailsHost,
        selectionDelegate: SubtensorSubnetSelectDelegate,
        interactor: SubtensorSubnetDetailsInteractorInputProtocol,
        wireframe: SubtensorSubnetDetailsWireframeProtocol,
        viewModelFactory: SubtensorSubnetDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.input = input
        self.host = host
        self.selectionDelegate = selectionDelegate
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory

        state = SubtensorSubnetDetailsState(
            validator: input.validator.map { .selected($0) } ?? (host == .picker ? .pending : .unselected)
        )

        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetDetailsPresenter {
    var subnetRef: SubtensorSubnetRef {
        input.subnet.ref
    }

    func provideTitle() {
        view?.didReceive(title: viewModelFactory.createTitle(subnetLogos: subnetLogos, locale: selectedLocale))
    }

    func provideViewModel() {
        state.now = Date()

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: state, locale: selectedLocale))
    }

    func loadHistory() {
        state.history = .loading
        interactor.loadHistory(for: state.period, registrationDate: registrationDate)
    }

    func historyNeedsRegistrationClip() -> Bool {
        guard let registrationDate else {
            return false
        }

        switch state.history {
        case .loading:
            return true
        case let .available(history):
            guard let firstDate = history.points.first?.date, let lastDate = history.points.last?.date else {
                return false
            }

            return registrationDate > (history.period.startDate(endingAt: lastDate) ?? firstDate)
        case .notListed, .failed:
            return false
        }
    }

    func existingPrimaryHotkey() -> AccountId? {
        positions.flatMap { SubtensorPortfolioBuilder.build(state: $0).group(netuid: subnetRef.netuid)?.primaryHotkey }
    }

    func requestParametersIfNeeded() {
        guard !isParametersRequested else {
            return
        }

        isParametersRequested = true
        interactor.loadParameters()
    }

    func requestPresetIfReady() {
        guard
            state.validator == .pending,
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
            selectedHotkey: state.validator.item?.hotkey,
            delegate: self
        )
    }
}

extension SubtensorSubnetDetailsPresenter: SubtensorSubnetDetailsPresenterProtocol {
    func setup() {
        provideTitle()
        provideViewModel()

        interactor.setup()
        requestParametersIfNeeded()
        interactor.loadHistory(for: state.period, registrationDate: registrationDate)
    }

    func selectCurrency(at index: Int) {
        let newIsFiat = index > 0

        guard newIsFiat != state.isFiat, !newIsFiat || state.taoPrice != nil else {
            provideViewModel()
            return
        }

        state.chartSelection = nil
        state.isFiat = newIsFiat
        provideViewModel()
    }

    func selectPeriod(at index: Int) {
        let periods = SubtensorPricePeriod.subnetSelectable

        guard periods.indices.contains(index), periods[index] != state.period, state.history != .notListed else {
            provideViewModel()
            return
        }

        state.period = periods[index]
        loadHistory()
        provideViewModel()
    }

    func toggleFavorite() {
        interactor.toggleFavorite()
    }

    func selectValidator() {
        showValidators(completesOnSelection: false)
    }

    func useSubnet() {
        switch state.validator {
        case .pending:
            return
        case let .selected(item):
            complete(with: item)
        case .unselected:
            showValidators(completesOnSelection: true)
        }
    }

    func retryHistory() {
        guard state.history == .failed else {
            return
        }

        loadHistory()
        provideViewModel()
    }

    func selectChart(_ selection: SubtensorPriceChartSelection?) {
        state.chartSelection = selection
        state.now = Date()

        let header = viewModelFactory.createPriceHeader(for: state, locale: selectedLocale)
        view?.didReceive(priceHeader: header)
    }
}

extension SubtensorSubnetDetailsPresenter: SubtensorSubnetDetailsInteractorOutputProtocol {
    func didReceive(isFavorite: Bool) {
        state.isFavorite = isFavorite
        provideViewModel()
    }

    func didReceiveHistory(_ history: SubtensorPriceHistory?, for period: SubtensorPricePeriod) {
        guard period == state.period else {
            return
        }

        state.chartEndDate = Date()
        state.history = history.map { .available($0) } ?? .notListed

        provideViewModel()
    }

    func didFailHistory(for period: SubtensorPricePeriod) {
        guard period == state.period else {
            return
        }

        if case .available = state.history {
            return
        }

        state.history = .failed
        provideViewModel()
    }

    func didReceiveParameters(_ parameters: SubtensorSubnetParameters) {
        guard parameters.ref == subnetRef else { return }
        state.parameters = parameters
        state.isParametersLoaded = true
        registrationDate = parameters.age.map { Date(timeIntervalSinceNow: -$0) }

        if historyNeedsRegistrationClip() {
            interactor.loadHistory(for: state.period, registrationDate: registrationDate)
        }

        provideViewModel()
    }

    func didFailParameters() {
        isParametersRequested = false
    }

    func didReceivePreset(_ validator: SubtensorValidatorDirectoryItem?) {
        guard state.validator == .pending else {
            return
        }

        state.validator = validator.map { .selected($0) } ?? .unselected
        provideViewModel()
    }

    func didFailPreset() {
        isPresetRequested = false
    }

    func didReceiveYields(_ yields: SubtensorAlphaYields?) {
        guard yields == nil || yields?.netuid == subnetRef.netuid else { return }
        state.yields = yields
        state.isRateResolved = true
        provideViewModel()
    }

    func didReceiveTaoPrice(_ price: PriceData?) {
        state.taoPrice = price
        provideViewModel()
    }

    func didChangeCurrency() {
        state.taoPrice = nil
        state.chartSelection = nil

        if state.history != .notListed {
            loadHistory()
        }

        provideViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorState?) {
        positions = state
        requestParametersIfNeeded()
        requestPresetIfReady()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed
        requestParametersIfNeeded()
        requestPresetIfReady()
    }

    func didBecomeActive() {
        requestParametersIfNeeded()
        requestPresetIfReady()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?) {
        subnetLogos = logos
        provideTitle()
    }
}

extension SubtensorSubnetDetailsPresenter: SubtensorValidatorSelectDelegate {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget) {
        guard target == input.target else { return }
        state.validator = .selected(validator)
        provideViewModel()
    }

    func didCompleteValidatorSelection(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget) {
        guard target == input.target, isUsePending else {
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
