import Foundation
import Foundation_iOS

final class SubtensorOperationResultPresenter {
    weak var view: SubtensorResultViewProtocol?
    weak var delegate: SubtensorOperationResultDelegate?

    let wireframe: SubtensorResultWireframeProtocol
    let interactor: SubtensorResultInteractorInputProtocol
    let viewModelFactory: SubtensorResultViewModelFactoryProtocol
    let request: SubtensorOperationResultRequest
    let stakingOption: Multistaking.ChainAssetOption

    private(set) var state: SubtensorOperationResultState = .progress
    private var catalogue: SubtensorSubnetCatalogue?
    private var subnetLogos: SubtensorSubnetLogos?
    private var expectedBlockTime: BlockTime = SubtensorStakingFlowConstants.blockTimeMillis
    private var countdownTimer: CountdownTimer?
    private var progressStartedAt = Date()

    init(
        request: SubtensorOperationResultRequest,
        stakingOption: Multistaking.ChainAssetOption,
        interactor: SubtensorResultInteractorInputProtocol,
        wireframe: SubtensorResultWireframeProtocol,
        viewModelFactory: SubtensorResultViewModelFactoryProtocol,
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
        TimeInterval(expectedBlockTime).seconds
    }

    func provideViewModel() {
        let context = SubtensorResultViewContext(
            request: request,
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

    func clearCountdown() {
        countdownTimer?.delegate = nil
        countdownTimer?.stop()
        countdownTimer = nil
    }

    func changeState(_ newState: SubtensorOperationResultState) {
        clearCountdown()
        state = newState
        provideViewModel()
    }

    func handleSuccess(_ outcome: SubtensorStakingOperationOutcome) {
        changeState(.done(outcome: outcome, time: Date()))

        interactor.fetchBlockTimestamp(at: outcome.blockHash)
    }

    func handleFailure(_ failure: SubtensorStakingSubmissionFailure) {
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
        case .notSubmitted:
            changeState(.failed(failure: failure, time: Date(), holdRemaining: nil))
        case let .dispatched(blockHash, _):
            changeState(.failed(failure: failure, time: Date(), holdRemaining: nil))

            interactor.fetchBlockTimestamp(at: blockHash)

            if (failure.error as? SubtensorStakingSubmissionError) == .rootStakeLocked {
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

extension SubtensorOperationResultPresenter: SubtensorResultPresenterProtocol {
    func setup() {
        if let catalogue = interactor.cachedCatalogue().value {
            self.catalogue = catalogue
        }

        progressStartedAt = Date()
        startCountdown()
        provideViewModel()

        interactor.setup()
    }

    func activate(action: SubtensorResultAction) {
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
            let subnetName = SubtensorSubnetNaming.titleWithSymbol(
                for: request.target.netuid,
                in: catalogue,
                locale: selectedLocale
            )

            wireframe.showSubtensorInfo(.swapRate(direction, subnetName: subnetName), from: view)
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

extension SubtensorOperationResultPresenter: SubtensorResultInteractorOutputProtocol {
    func didReceiveSubmission(result: Result<SubtensorStakingOperationOutcome, SubtensorStakingSubmissionFailure>) {
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

    func didReachConfirmationCap() {
        guard case .progress = state else {
            return
        }

        changeState(.unconfirmed(time: Date()))
    }

    func didReceiveExpectedBlockTime(_ blockTime: BlockTime) {
        expectedBlockTime = blockTime

        guard case .progress = state else {
            return
        }

        startCountdown()
        provideViewModel()
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

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue) {
        self.catalogue = catalogue
        provideViewModel()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos) {
        subnetLogos = logos
        provideViewModel()
    }

    func didBecomeActive() {
        guard case .unconfirmed = state else {
            return
        }

        interactor.refreshPositions()
    }
}

extension SubtensorOperationResultPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval: TimeInterval) {
        view?.didUpdateCountdown(remainedTime: UInt(remainedInterval.rounded(.up)))
    }

    func didStop(with remainedInterval: TimeInterval) {
        view?.didUpdateCountdown(remainedTime: UInt(remainedInterval.rounded(.up)))
    }
}

extension SubtensorOperationResultPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}

private extension SubtensorStakingSubmissionFailure.Stage {
    var blockHash: BlockHash? {
        if case let .dispatched(blockHash, _) = self {
            return blockHash
        }

        return nil
    }
}
