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
        interactor: StartStakingInfoRelaychainInteractorInputProtocol,
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
        logger?.error("Did receive error: \(error)")

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
        case .accountRemoteSubscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeAccountRemoteSubscription()
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
        var rewardsDestination: RewardDestinationModel { .stake }

        var minStake: BigUInt? {
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

        var directStakingMinStake: BigUInt? {
            // TODO: add nomination pool min staking
            minStake
        }

        var unstakingTime: TimeInterval? {
            guard let networkInfo = networkInfo else {
                return nil
            }

            return networkInfo.stakingDuration.unlocking
        }
    }
}
