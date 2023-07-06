import Foundation
import SoraFoundation
import BigInt

final class StartStakingInfoRelaychainPresenter: StartStakingInfoBasePresenter {
    let interactor: StartStakingInfoInteractorInputProtocol

    private var minNominatorBond: LoadableViewModelState<BigUInt?> = .loading
    private var bagListSize: LoadableViewModelState<UInt32?> = .loading
    private var networkInfo: LoadableViewModelState<NetworkStakingInfo?> = .loading
    private var eraCountdown: LoadableViewModelState<EraCountdown?> = .loading

    override init(
        interactor: StartStakingInfoInteractorInputProtocol,
        dashboardItem: Multistaking.DashboardItem,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor

        super.init(
            interactor: interactor,
            dashboardItem: dashboardItem,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            localizationManager: localizationManager
        )
    }

    private func provideViewModel() {
        guard let stakingType = startStakingType(),
              let chainAsset = chainAsset,
              let eraDuration = eraDuration(),
              let networkInfo = networkInfo.value,
              let unstakePeriod = networkInfo?.stakingDuration.unlocking,
              let nominationEraValue = nextEraTime(),
              let minStake = minStake() else {
            return
        }

        let maxApy = dashboardItem.maxApy
        let title = startStakingViewModelFactory.earnupModel(
            earnings: maxApy,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        let wikiUrl = startStakingViewModelFactory.wikiModel(
            locale: selectedLocale,
            url: URL(string: "https://novawallet.io")!
        )
        let termsUrl = startStakingViewModelFactory.termsModel(
            locale: selectedLocale,
            url: URL(string: "https://novawallet.io")!
        )
        let testnetModel = chainAsset.chain.isTestnet ? startStakingViewModelFactory.testNetworkModel(
            chain: chainAsset.chain,
            locale: selectedLocale
        ) : nil

        let govModel = chainAsset.chain.hasGovernance ? startStakingViewModelFactory.govModel(
            stakingType: stakingType,
            chainAsset: chainAsset,
            locale: selectedLocale
        ) : nil

        let paragraphs = [
            testnetModel,
            startStakingViewModelFactory.stakeModel(
                minStake: minStake,
                nextEra: nominationEraValue,
                chainAsset: chainAsset,
                locale: selectedLocale
            ),
            startStakingViewModelFactory.unstakeModel(unstakePeriod: unstakePeriod, locale: selectedLocale),
            startStakingViewModelFactory.rewardModel(
                stakingType: stakingType,
                chainAsset: chainAsset,
                eraDuration: eraDuration,
                locale: selectedLocale
            ),
            govModel,
            startStakingViewModelFactory.recommendationModel(locale: selectedLocale)
        ].compactMap { $0 }

        let model = StartStakingViewModel(
            title: title,
            paragraphs: paragraphs,
            wikiUrl: wikiUrl,
            termsUrl: termsUrl
        )
        view?.didReceive(viewModel: .loaded(value: model))
    }

    private func minStake() -> BigUInt? {
        guard let networkInfo = networkInfo.value,
              let minNominatorBond = minNominatorBond.value,
              let bagListSize = bagListSize.value else {
            return nil
        }

        return networkInfo?.calculateMinimumStake(
            given: minNominatorBond,
            votersCount: bagListSize
        )
    }

    private func nextEraTime() -> TimeInterval? {
        guard let eraCountdownResult = eraCountdown.value, let eraCountdown = eraCountdownResult else {
            return nil
        }

        return eraCountdown.timeIntervalTillStart(targetEra: eraCountdown.activeEra + 1)
    }

    private func eraDuration() -> TimeInterval? {
        guard let eraCountdownResult = eraCountdown.value else {
            return nil
        }

        return eraCountdownResult?.eraTimeInterval
    }

    private func startStakingType() -> StartStakingType? {
        guard let assetBalance = assetBalance else {
            return nil
        }
        guard let minStake = minStake() else {
            return nil
        }

        if assetBalance.freeInPlank >= minStake {
            return .directStaking(amount: minStake)
        } else {
            return .nominationPool
        }
    }

    override func setup() {
        super.setup()
        interactor.setup()
    }
}

extension StartStakingInfoRelaychainPresenter: StartStakingInfoRelaychainInteractorOutputProtocol {
    func didReceive(minNominatorBond: BigUInt?) {
        self.minNominatorBond = .loaded(value: minNominatorBond)
        provideViewModel()
    }

    func didReceive(bagListSize: UInt32?) {
        self.bagListSize = .loaded(value: bagListSize)
        provideViewModel()
    }

    func didReceive(networkInfo: NetworkStakingInfo?) {
        self.networkInfo = .loaded(value: networkInfo)
        provideViewModel()
    }

    func didReceive(eraCountdown: EraCountdown?) {
        self.eraCountdown = .loaded(value: eraCountdown)
        provideViewModel()
    }

    func didReceive(error _: RelaychainStartStakingInfoError) {}
}
