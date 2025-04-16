import Foundation
import BigInt
import Foundation_iOS

final class StartStakingInfoMythosPresenter: StartStakingInfoBasePresenter {
    private var state: State {
        didSet {
            if state != oldValue {
                provideViewModel(state: state)
            }
        }
    }

    var interator: StartStakingInfoMythosInteractorInputProtocol? {
        baseInteractor as? StartStakingInfoMythosInteractorInputProtocol
    }

    init(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoMythosInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        state = .init(chainAsset: chainAsset, minStake: nil)

        super.init(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            balanceDerivationFactory: balanceDerivationFactory,
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

extension StartStakingInfoMythosPresenter: StartStakingInfoMythosInteractorOutputProtocol {
    func didReceive(duration: MythosStakingDuration) {
        logger.debug("Duration: \(duration)")

        state.duration = duration
    }

    func didReceive(blockNumber: BlockNumber?) {
        logger.debug("Block number: \(String(describing: blockNumber))")

        state.update(blockNumber: blockNumber)
    }

    func didReceive(currentSession: SessionIndex) {
        logger.debug("Current session: \(currentSession)")

        state.currentSession = currentSession
    }

    func didReceive(minStake: Balance) {
        logger.debug("Min stake: \(minStake)")

        state.minStake = minStake
    }

    func didReceive(calculator: CollatorStakingRewardCalculatorEngineProtocol) {
        let maxApy = calculator.calculateMaxReturn(for: .year)

        logger.debug("Max APY: \(maxApy.stringWithPointSeparator)")

        state.maxApy = maxApy
    }
}

extension StartStakingInfoMythosPresenter {
    struct State: StartStakingStateProtocol, Equatable {
        let chainAsset: ChainAsset
        var minStake: Balance?
        var duration: MythosStakingDuration?
        var currentSession: SessionIndex?
        var maxApy: Decimal?

        private(set) var blockNumber: BlockNumber?

        var rewardTime: TimeInterval? { duration?.session }

        var unstakingTime: TimeInterval? { duration?.unstaking }

        var rewardDelay: TimeInterval? {
            guard let currentSession else {
                return nil
            }

            return sessionCountdown?.timeIntervalTillStart(
                targetSession: currentSession + 2
            )
        }

        var sessionCountdown: ChainSessionCountdown? {
            guard let blockNumber, let duration, let currentSession else {
                return nil
            }
            return ChainSessionCountdown(
                currentSession: currentSession,
                info: duration.sessionInfo,
                blockTime: duration.block,
                currentBlock: blockNumber,
                createdAtDate: Date()
            )
        }

        var rewardsAutoPayoutThresholdAmount: BigUInt? { nil }

        var govThresholdAmount: BigUInt? { nil }

        var shouldHaveGovInfo: Bool {
            chainAsset.chain.hasGovernance
        }

        var rewardsDestination: DefaultStakingRewardDestination { .manual }

        mutating func update(blockNumber: BlockNumber?) {
            self.blockNumber = blockNumber
        }
    }
}
