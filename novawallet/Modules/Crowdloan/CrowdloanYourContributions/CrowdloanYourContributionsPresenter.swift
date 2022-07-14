import Foundation
import SoraFoundation

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol
    let input: CrowdloanYourContributionsViewInput
    let viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol
    let timeFormatter: TimeFormatterProtocol
    let logger: LoggerProtocol?

    private var returnInIntervals: [TimeInterval]?
    private var maxReturnInInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?

    private var externalContributions: [ExternalContribution]?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var leasingPeriod: LeasingPeriod?
    private var price: PriceData?

    private var crowloanMetadata: CrowdloanMetadata? {
        guard
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod else {
            return nil
        }

        return CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration,
            leasingPeriod: leasingPeriod
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
        logger: LoggerProtocol? = nil
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.timeFormatter = timeFormatter
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateCrowdloans() {
        let viewModel = viewModelFactory.createViewModel(
            input: input,
            externalContributions: externalContributions,
            price: price,
            locale: selectedLocale
        )

        view?.reload(contributions: viewModel.contributions)
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

        maxReturnInInterval = returnInIntervals?.max()

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

        let returnInViewModels: [String?] = returnInIntervals?.map { timeInterval in
            guard timeInterval >= elapsedTime else {
                return nil
            }

            let remainedTime = timeInterval - elapsedTime

            if remainedTime.daysFromSeconds > 0 {
                return remainedTime.localizedDaysHours(for: selectedLocale)
            } else {
                return try? timeFormatter.string(from: remainedTimeInterval)
            }
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
