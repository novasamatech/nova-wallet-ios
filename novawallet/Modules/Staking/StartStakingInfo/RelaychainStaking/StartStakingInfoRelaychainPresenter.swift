import Foundation
import SoraFoundation
import BigInt

final class StartStakingInfoRelaychainPresenter: StartStakingInfoBasePresenter {
    let interactor: StartStakingInfoRelaychainInteractorInputProtocol

    private var state: State = .init() {
        didSet {
            provideViewModel(state: state)
        }
    }

    init(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoRelaychainInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor

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

extension StartStakingInfoRelaychainPresenter: StartStakingInfoRelaychainInteractorOutputProtocol {
    func didReceive(eraCountdown: EraCountdown?) {
        if shouldUpdateEraDuration(
            for: eraCountdown?.eraTimeInterval,
            oldValue: state.eraCountdown?.eraTimeInterval
        ) {
            state.eraCountdown = eraCountdown
        }
    }

    func didReceive(networkInfo: NetworkStakingInfo) {
        state.networkInfo = networkInfo
    }

    func didReceive(directStakingMinStake: BigUInt) {
        state.directStakingMinimumStake = directStakingMinStake
    }

    func didReceive(nominationPoolMinStake: BigUInt?) {
        state.nominationPoolMinimumStake = nominationPoolMinStake
    }

    func didReceive(error: RelaychainStartStakingInfoError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .directStakingMinStake:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryDirectStakingMinStake()
            }
        case .createState:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .eraCountdown:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryEraCompletionTime()
            }
        case .nominationPoolsMinStake:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryNominationPoolsMinStake()
            }
        case .calculator:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeCalculator()
            }
        }
    }

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        state.maxApy = calculator.calculateMaxEarnings(amount: 1, isCompound: true, period: .year)
    }
}

extension StartStakingInfoRelaychainPresenter {
    struct State: StartStakingStateProtocol {
        var networkInfo: NetworkStakingInfo?
        var eraCountdown: EraCountdown?
        var maxApy: Decimal?
        var rewardsDestination: DefaultStakingRewardDestination { .stake }
        var nominationPoolMinimumStake: BigUInt?
        var directStakingMinimumStake: BigUInt?

        var minStake: BigUInt? {
            if let nominationPoolMinimumStake = nominationPoolMinimumStake,
               let directStakingMinimumStake = directStakingMinimumStake {
                return min(nominationPoolMinimumStake, directStakingMinimumStake)
            } else {
                return directStakingMinimumStake
            }
        }

        var nextEraStartTime: TimeInterval? {
            guard let eraCountdown = eraCountdown else {
                return nil
            }

            return eraCountdown.timeIntervalTillStart(targetEra: eraCountdown.currentEra + 2)
        }

        var eraDuration: TimeInterval? {
            guard let eraCountdown = eraCountdown else {
                return nil
            }

            return eraCountdown.eraTimeInterval
        }

        var rewardsAutoPayoutThresholdAmount: BigUInt? {
            guard
                nominationPoolMinimumStake != nil,
                let directStakingMinimumStake = directStakingMinimumStake,
                let minStake = minStake else {
                return nil
            }

            return directStakingMinimumStake <= minStake ? nil : directStakingMinimumStake
        }

        var govThresholdAmount: BigUInt? {
            rewardsAutoPayoutThresholdAmount
        }

        var unstakingTime: TimeInterval? {
            guard let networkInfo = networkInfo else {
                return nil
            }

            return networkInfo.stakingDuration.unlocking
        }
    }
}
