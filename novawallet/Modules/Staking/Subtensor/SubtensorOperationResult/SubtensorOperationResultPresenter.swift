import Foundation
import Foundation_iOS

final class SubtensorOperationResultPresenter {
    weak var view: SubtensorOperationResultViewProtocol?
    weak var delegate: SubtensorOperationResultDelegate?

    let wireframe: SubtensorOperationResultWireframeProtocol
    let interactor: SubtensorOperationResultInteractorInputProtocol
    let viewModelFactory: SubtensorOperationResultViewModelFactoryProtocol
    let request: SubtensorOperationResultRequest
    let stakingOption: Multistaking.ChainAssetOption

    private(set) var state: SubtensorOperationResultState = .progress
    private var route: SubtensorSubmissionRoute?
    private var catalogue: SubtensorSubnetCatalogue?
    private var subnetLogos: SubtensorSubnetLogos?
    private var countdownTimer: CountdownTimer?
    private var pendingKeyRetries = 0
    private(set) var progressStartedAt = Date()
    var isOutcomeTracked = false

    init(
        request: SubtensorOperationResultRequest,
        stakingOption: Multistaking.ChainAssetOption,
        interactor: SubtensorOperationResultInteractorInputProtocol,
        wireframe: SubtensorOperationResultWireframeProtocol,
        viewModelFactory: SubtensorOperationResultViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.request = request
        self.stakingOption = stakingOption
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    deinit {
        clearCountdown()
    }
}

private extension SubtensorOperationResultPresenter {
    var expectedBlockDuration: TimeInterval {
        request.blockTime.timeInterval
    }

    func provideViewModel() {
        let context = SubtensorResultViewContext(
            request: request,
            route: route ?? (request.shieldQuote != nil ? .shielded : .clear),
            catalogue: catalogue,
            subnetLogos: subnetLogos,
            remainedTime: countdownTimer?.remainedInterval ?? 0
        )

        let viewModel = viewModelFactory.createViewModel(for: state, context: context, locale: selectedLocale)

        view?.didReceive(viewModel: viewModel)
    }

    func startCountdown() {
        let elapsed = Date().timeIntervalSince(progressStartedAt)
        let timer = countdownTimer ?? CountdownTimer()

        timer.stop()
        timer.delegate = self
        timer.start(with: max(0, expectedBlockDuration - elapsed))

        countdownTimer = timer
    }

    func extendCountdownForKeyRetry() {
        pendingKeyRetries -= 1

        countdownTimer?.start(with: expectedBlockDuration)
        view?.didUpdateCountdown(remainedTime: UInt(expectedBlockDuration.rounded(.up)))
    }

    func clearCountdown() {
        pendingKeyRetries = 0
        countdownTimer?.delegate = nil
        countdownTimer?.stop()
        countdownTimer = nil
    }

    func changeState(_ newState: SubtensorOperationResultState) {
        clearCountdown()
        state = newState
        provideViewModel()
    }

    func handleSuccess(_ outcome: SubtensorOperationOutcome) {
        trackSuccess(outcome)
        changeState(.done(outcome: outcome, time: Date()))

        interactor.fetchBlockTimestamp(at: outcome.blockHash)
    }

    func handleFailure(_ failure: SubtensorSubmissionFailure) {
        trackFailure(failure)

        if failure.isSigningCancelled {
            clearCountdown()
            retry()
            return
        }

        if failure.isSigningRefused {
            clearCountdown()
            wireframe.presentSigningFailure(failure.error, from: view)
            return
        }

        switch failure.stage {
        case .notSubmitted, .notExecutedFeeUnknown:
            changeState(.failed(failure: failure, time: Date(), holdRemaining: nil))
        case let .dispatched(blockHash, _):
            changeState(.failed(failure: failure, time: Date(), holdRemaining: nil))

            interactor.fetchBlockTimestamp(at: blockHash)

            if (failure.error as? SubtensorSubmissionError) == .rootStakeLocked {
                interactor.fetchRootHoldRemainingBlocks(for: request.operation.rootHotkeys)
            }
        case .unconfirmed:
            if case .unconfirmed = state {
                return
            }

            changeState(.unconfirmed(time: Date()))
        }
    }

    func retry() {
        let delegate = delegate

        wireframe.closeForRetry(from: view) {
            delegate?.didRequestRetry()
        }
    }

    func completeAfterSuccess() {
        if request.origin == .newPosition || request.emptiesPosition {
            wireframe.showYourBittensor(from: view, stakingOption: stakingOption)
        } else {
            wireframe.closeOperation(from: view)
        }
    }

    func costBasisInfo(for direction: SubtensorTradeDirection) -> SubtensorInfoSheet {
        switch direction {
        case .sell:
            return .youWillEarn
        case .buy:
            let netuid = request.target.netuid

            return .avgBuyPrice(
                symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue),
                subnetName: SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: selectedLocale)
            )
        }
    }
}

extension SubtensorOperationResultPresenter: SubtensorOperationResultPresenterProtocol {
    func setup() {
        progressStartedAt = Date()
        startCountdown()
        provideViewModel()

        interactor.setup()
    }

    func activate(action: SubtensorResultAction) {
        trackAction(action)

        switch action {
        case .done:
            completeAfterSuccess()
        case .tryAgain:
            retry()
        case .close, .backToPosition:
            wireframe.closeOperation(from: view)
        case .viewPosition, .yourBittensor:
            wireframe.showYourBittensor(from: view, stakingOption: stakingOption)
        case .discoverSubnets:
            trackSubnetDiscovery()
            wireframe.showSubnetDiscovery(from: view)
        }
    }

    func goBack() {
        switch state {
        case .progress:
            break
        case .failed:
            retry()
        case .done, .unconfirmed:
            completeAfterSuccess()
        }
    }

    func showInfo(for row: SubtensorResultInfoRow) {
        let direction = request.operation.tradeDirection ?? .buy

        switch row {
        case .swapRate:
            guard let novaFeeRate = request.quote?.novaFeeRate else {
                return
            }

            let subnetName = SubtensorSubnetNaming.titleWithSymbol(
                for: request.target.netuid,
                in: catalogue,
                locale: selectedLocale
            )

            wireframe.showSubtensorInfo(
                .swapRate(direction, subnetName: subnetName, novaFeeRate: novaFeeRate),
                from: view
            )
        case .costBasis:
            wireframe.showSubtensorInfo(costBasisInfo(for: direction), from: view)
        case .slippage:
            let tolerance = request.slippage ?? SubtensorSlippageTolerance.defaultTolerance
            wireframe.showSubtensorInfo(.slippage(tolerance, canEdit: false), from: view)
        case .validator:
            wireframe.showValidatorInfo(
                from: view,
                target: request.target,
                hotkey: request.validator.hotkey,
                detail: nil
            )
        case .networkFee:
            wireframe.showSubtensorInfo(.networkFee(direction), from: view)
        }
    }
}

extension SubtensorOperationResultPresenter: SubtensorOperationResultInteractorOutputProtocol {
    func didReceiveSubmission(result: Result<SubtensorOperationOutcome, SubtensorSubmissionFailure>) {
        guard state.acceptsSubmissionResult else {
            return
        }

        switch result {
        case let .success(outcome):
            handleSuccess(outcome)
        case let .failure(failure):
            handleFailure(failure)
        }
    }

    func didPostponeSigning() {
        guard case .progress = state, let countdownTimer else {
            return
        }

        pendingKeyRetries += 1

        if case .stopped = countdownTimer.state {
            extendCountdownForKeyRetry()
        }
    }

    func didSelectRoute(_ route: SubtensorSubmissionRoute) {
        self.route = route
        pendingKeyRetries = 0

        provideViewModel()
    }

    func didReachConfirmationCap() {
        guard case .progress = state else {
            return
        }

        trackUnconfirmed()
        changeState(.unconfirmed(time: Date()))
    }

    func didReceiveBlockTimestamp(_ date: Date, at blockHash: BlockHash) {
        switch state {
        case let .done(outcome, _) where outcome.blockHash == blockHash:
            state = .done(outcome: outcome, time: date)
        case let .failed(failure, _, holdRemaining) where failure.stage.blockHash == blockHash:
            state = .failed(failure: failure, time: date, holdRemaining: holdRemaining)
        default:
            return
        }

        provideViewModel()
    }

    func didReceiveRootHoldRemainingBlocks(_ blocks: UInt64) {
        guard case let .failed(failure, time, _) = state else {
            return
        }

        state = .failed(failure: failure, time: time, holdRemaining: TimeInterval(blocks) * expectedBlockDuration)

        provideViewModel()
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        self.catalogue = catalogue
        provideViewModel()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos) {
        subnetLogos = logos
        provideViewModel()
    }
}

extension SubtensorOperationResultPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval: TimeInterval) {
        view?.didUpdateCountdown(remainedTime: UInt(remainedInterval.rounded(.up)))
    }

    func didStop(with remainedInterval: TimeInterval) {
        if pendingKeyRetries > 0 {
            extendCountdownForKeyRetry()
        } else {
            view?.didUpdateCountdown(remainedTime: UInt(remainedInterval.rounded(.up)))
        }
    }
}

extension SubtensorOperationResultPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}

private extension SubtensorSubmissionFailure.Stage {
    var blockHash: BlockHash? {
        if case let .dispatched(blockHash, _) = self {
            return blockHash
        }

        return nil
    }
}
