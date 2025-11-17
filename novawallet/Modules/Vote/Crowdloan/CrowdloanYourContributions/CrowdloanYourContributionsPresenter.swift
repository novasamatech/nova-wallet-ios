import Foundation
import Foundation_iOS
import Operation_iOS

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanContributionsViewProtocol?
    let wireframe: CrowdloanContributionsWireframeProtocol
    let interactor: CrowdloanContributionsInteractorInputProtocol
    let viewModelFactory: CrowdloanContributionsVMFactoryProtocol
    let timeFormatter: TimeFormatterProtocol
    let logger: LoggerProtocol?

    private var input: CrowdloanYourContributionsViewInput

    private var returnInIntervals: [ReturnInIntervalsViewModel]?
    private var maxReturnInInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?

    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var price: PriceData?

    private var crowloanMetadata: CrowdloanMetadata? {
        guard
            let blockNumber = blockNumber,
            let blockDuration = blockDuration else {
            return nil
        }

        return CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration
        )
    }

    deinit {
        invalidateTimer()
    }

    init(
        input: CrowdloanYourContributionsViewInput,
        viewModelFactory: CrowdloanContributionsVMFactoryProtocol,
        interactor: CrowdloanContributionsInteractorInputProtocol,
        wireframe: CrowdloanContributionsWireframeProtocol,
        timeFormatter: TimeFormatterProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
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

extension CrowdloanYourContributionsPresenter: CrowdloanContributionsPresenterProtocol {
    func setup() {
        updateCrowdloans()
        interactor.setup()
    }

    func unlock() {}
}

extension CrowdloanYourContributionsPresenter: CrowdloanContributionsInteractorOutputProtocol {
    func didReceiveContributions(_ changes: [DataProviderChange<CrowdloanContribution>]) {
        input = input.applyingChanges(changes)

        updateCrowdloans()
        updateReturnInTimeIntervals()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber?) {
        self.blockNumber = blockNumber

        updateReturnInTimeIntervals()
    }

    func didReceiveBlockDuration(_ blockDuration: BlockTime) {
        self.blockDuration = blockDuration

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
