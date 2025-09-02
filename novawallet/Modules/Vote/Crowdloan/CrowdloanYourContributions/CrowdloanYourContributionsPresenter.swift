import Foundation
import Foundation_iOS

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol
    let input: CrowdloanYourContributionsViewInput
    let viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol
    let timeFormatter: TimeFormatterProtocol
    let logger: LoggerProtocol?
    let crowdloansCalculator: CrowdloansCalculatorProtocol

    private var returnInIntervals: [ReturnInIntervalsViewModel]?
    private var maxReturnInInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?

    private var externalContributions: [ExternalContribution]?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var leasingPeriod: LeasingPeriod?
    private var leasingOffset: LeasingOffset?
    private var price: PriceData?

    private var crowloanMetadata: CrowdloanMetadata? {
        guard
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod,
            let leasingOffset = leasingOffset else {
            return nil
        }

        return CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration,
            leasingPeriod: leasingPeriod,
            leasingOffset: leasingOffset
        )
    }

    deinit {
        invalidateTimer()
    }

    init(
        input: CrowdloanYourContributionsViewInput,
        viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol,
        interactor: CrowdloanYourContributionsInteractorInputProtocol,
        wireframe: CrowdloanYourContributionsWireframeProtocol,
        timeFormatter: TimeFormatterProtocol,
        localizationManager: LocalizationManagerProtocol,
        crowdloansCalculator: CrowdloansCalculatorProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.timeFormatter = timeFormatter
        self.logger = logger
        self.crowdloansCalculator = crowdloansCalculator
        self.localizationManager = localizationManager
    }

    private func updateCrowdloans() {
        let amount = crowdloansCalculator.calculateTotal(
            precision: input.chainAsset.asset.assetPrecision,
            contributions: input.contributions,
            externalContributions: externalContributions
        )
        let viewModel = viewModelFactory.createViewModel(
            input: input,
            externalContributions: externalContributions,
            amount: amount ?? 0,
            price: price,
            locale: selectedLocale
        )

        view?.reload(model: viewModel)
    }

    private func updateReturnInTimeIntervals() {
        guard let crowloanMetadata = crowloanMetadata else {
            return
        }

        returnInIntervals = viewModelFactory.createReturnInIntervals(
            input: input,
            externalContributions: externalContributions,
            metadata: crowloanMetadata
        )

        maxReturnInInterval = returnInIntervals?.max { $0.interval < $1.interval }?.interval

        invalidateTimer()
        setupTimer()

        updateTimerDisplay()
    }

    private func invalidateTimer() {
        countdownTimer?.stop()
        countdownTimer = nil
    }

    private func setupTimer() {
        guard let maxReturnInInterval = maxReturnInInterval else {
            return
        }

        countdownTimer = CountdownTimer()
        countdownTimer?.delegate = self
        countdownTimer?.start(with: maxReturnInInterval)
    }

    private func updateTimerDisplay() {
        guard
            let maxReturnInInterval = maxReturnInInterval,
            let remainedTimeInterval = countdownTimer?.remainedInterval else {
            return
        }

        let elapsedTime = maxReturnInInterval >= remainedTimeInterval ? maxReturnInInterval - remainedTimeInterval : 0

        let returnInViewModels: [FormattedReturnInIntervalsViewModel] = returnInIntervals?.map { model in
            guard model.interval > elapsedTime else {
                return .init(index: model.index, interval: nil)
            }

            let remainedTime = model.interval - elapsedTime

            let remainedTimeString: String?
            if remainedTime.daysFromSeconds > 0 {
                remainedTimeString = remainedTime.localizedDaysHours(for: selectedLocale)
            } else {
                remainedTimeString = try? timeFormatter.string(from: remainedTime)
            }
            return .init(index: model.index, interval: remainedTimeString)
        } ?? []

        view?.reload(returnInIntervals: returnInViewModels)
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsPresenterProtocol {
    func setup() {
        updateCrowdloans()
        interactor.setup()
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsInteractorOutputProtocol {
    func didReceiveExternalContributions(_ externalContributions: [ExternalContribution]) {
        let positiveContributions = externalContributions.filter { $0.amount > 0 }
        self.externalContributions = positiveContributions
        if !positiveContributions.isEmpty {
            updateCrowdloans()
            updateReturnInTimeIntervals()
        }
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber?) {
        self.blockNumber = blockNumber

        updateReturnInTimeIntervals()
    }

    func didReceiveBlockDuration(_ blockDuration: BlockTime) {
        self.blockDuration = blockDuration

        updateReturnInTimeIntervals()
    }

    func didReceiveLeasingPeriod(_ leasingPeriod: LeasingPeriod) {
        self.leasingPeriod = leasingPeriod

        updateReturnInTimeIntervals()
    }

    func didReceiveLeasingOffset(_ leasingOffset: LeasingOffset) {
        self.leasingOffset = leasingOffset

        updateReturnInTimeIntervals()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        updateCrowdloans()
    }

    func didReceiveError(_ error: Error) {
        logger?.error("Did receive external contributions error: \(error)")
    }
}

extension CrowdloanYourContributionsPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateTimerDisplay()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateTimerDisplay()
    }

    func didStop(with _: TimeInterval) {
        updateTimerDisplay()
    }
}

extension CrowdloanYourContributionsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateCrowdloans()
            updateTimerDisplay()
        }
    }
}
