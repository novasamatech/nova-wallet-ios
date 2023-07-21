import SoraFoundation
import BigInt

final class StartStakingInfoParachainPresenter: StartStakingInfoBasePresenter {
    let interactor: StartStakingInfoParachainInteractorInputProtocol

    private var state: State = .init() {
        didSet {
            if state != oldValue {
                provideViewModel(state: state)
            }
        }
    }

    init(
        interactor: StartStakingInfoParachainInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            localizationManager: localizationManager,
            applicationConfig: applicationConfig,
            logger: logger
        )
    }

    override func setup() {
        super.setup()
        view?.didReceive(viewModel: .loading)
    }
}

extension StartStakingInfoParachainPresenter: StartStakingInfoParachainInteractorOutputProtocol {
    func didReceive(networkInfo: ParachainStaking.NetworkInfo?) {
        state.networkInfo = networkInfo
    }

    func didReceive(error: ParachainStartStakingInfoError) {
        logger?.error("Did receive error: \(error)")

        switch error {
        case let .networkInfo(error):
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryNetworkStakingInfo()
            }
        case .createState:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .calculator:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeCalculator()
            }
        case .stakingDuration:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryStakingDuration()
            }
        case .rewardPaymentDelay:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryRewardPaymentDelay()
            }
        case .blockNumber, .parastakingRound:
            break
        }
    }

    func didReceive(parastakingRound roundInfo: ParachainStaking.RoundInfo?) {
        state.roundInfo = roundInfo
    }

    func didReceive(calculator: ParaStakingRewardCalculatorEngineProtocol) {
        state.maxApy = calculator.calculateMaxEarnings(amount: 1, period: .year)
    }

    func didReceive(blockNumber: BlockNumber?) {
        state.update(blockNumber: blockNumber)
    }

    func didReceive(stakingDuration: ParachainStakingDuration) {
        state.stakingDuration = stakingDuration
    }

    func didReceive(rewardPaymentDelay: UInt32) {
        state.rewardPaymentDelay = rewardPaymentDelay
    }
}

extension StartStakingInfoParachainPresenter {
    struct State: StartStakingStateProtocol, Equatable {
        var networkInfo: ParachainStaking.NetworkInfo?
        var roundInfo: ParachainStaking.RoundInfo?
        var maxApy: Decimal?
        private(set) var blockNumber: BlockNumber?
        var stakingDuration: ParachainStakingDuration?
        var rewardPaymentDelay: UInt32?
        var rewardsDestination: DefaultStakingRewardDestination { .balance }

        var minStake: BigUInt? {
            guard let networkInfo = networkInfo else {
                return nil
            }

            return max(networkInfo.minStakeForRewards, networkInfo.minTechStake)
        }

        var govThresholdAmount: BigUInt? { nil }

        var rewardsAutoPayoutThresholdAmount: BigUInt? { nil }

        var nextEraStartTime: TimeInterval? {
            guard let roundCountdown = roundCountdown,
                  let roundInfo = roundInfo,
                  let rewardPaymentDelay = rewardPaymentDelay else {
                return nil
            }

            return roundCountdown.timeIntervalTillStart(targetEra: roundInfo.current + 1 + rewardPaymentDelay)
        }

        var roundCountdown: RoundCountdown? {
            guard let blockNumber = blockNumber,
                  let roundInfo = roundInfo,
                  let stakingDuration = stakingDuration else {
                return nil
            }
            return RoundCountdown(
                roundInfo: roundInfo,
                blockTime: stakingDuration.block,
                currentBlock: blockNumber,
                createdAtDate: Date()
            )
        }

        var unstakingTime: TimeInterval? {
            guard let stakingDuration = stakingDuration else {
                return nil
            }

            return stakingDuration.unstaking
        }

        var eraDuration: TimeInterval? {
            guard let stakingDuration = stakingDuration else {
                return nil
            }

            return stakingDuration.round
        }

        mutating func update(blockNumber: BlockNumber?) {
            guard let blockNumber = blockNumber, self.blockNumber == nil else {
                return
            }

            self.blockNumber = blockNumber
        }
    }
}
