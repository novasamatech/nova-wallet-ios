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
    func didReceive(minNominatorBond: BigUInt?) {
        state.minNominatorBond = .loaded(value: minNominatorBond)
    }

    func didReceive(bagListSize: UInt32?) {
        state.bagListSize = .loaded(value: bagListSize)
    }

    func didReceive(networkInfo: NetworkStakingInfo?) {
        state.networkInfo = networkInfo
    }

    func didReceive(eraCountdown: EraCountdown?) {
        state.eraCountdown = eraCountdown
    }

    func didReceive(error: RelaychainStartStakingInfoError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .networkStakingInfo:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryNetworkStakingInfo()
            }
        case .createState:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .eraCountdown:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryEraCompletionTime()
            }
        case .bagListSize:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeBagListSizeSubscription()
            }
        case .minNominatorBond:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeMinNominatorBondSubscription()
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
        var minNominatorBond: LoadableViewModelState<BigUInt?> = .loading
        var bagListSize: LoadableViewModelState<UInt32?> = .loading
        var networkInfo: NetworkStakingInfo?
        var eraCountdown: EraCountdown?
        var maxApy: Decimal?
        var rewardsDestination: DefaultStakingRewardDestination { .stake }
        var chainAsset: ChainAsset?

        // TODO:
        var nominationPoolMinimumStake: BigUInt?

        var directStakingMinimumStake: BigUInt? {
            guard let networkInfo = networkInfo,
                  let minNominatorBond = minNominatorBond.value,
                  let bagListSize = bagListSize.value else {
                return nil
            }

            return networkInfo.calculateMinimumStake(
                given: minNominatorBond,
                votersCount: bagListSize
            )
        }

        var minStake: BigUInt? {
            guard let chainAsset = chainAsset else {
                return nil
            }

            if chainAsset.asset.supportedStakings?.contains(.nominationPools) == true {
                if let nominationPoolMinimumStake = nominationPoolMinimumStake,
                   let directStakingMinimumStake = directStakingMinimumStake {
                    return min(nominationPoolMinimumStake, directStakingMinimumStake)
                } else {
                    // TODO: return nil
                    return directStakingMinimumStake
                }
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
            guard let chainAsset = chainAsset else {
                return nil
            }
            guard chainAsset.asset.supportedStakings?.contains(.nominationPools) == true else {
                return nil
            }

            guard let directStakingMinimumStake = directStakingMinimumStake,
                  let minStake = minStake else {
                return nil
            }

            return directStakingMinimumStake == minStake ? nil : directStakingMinimumStake
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
