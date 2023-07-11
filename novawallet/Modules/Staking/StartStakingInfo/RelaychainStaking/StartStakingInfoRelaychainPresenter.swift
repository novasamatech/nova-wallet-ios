import Foundation
import SoraFoundation
import BigInt

final class StartStakingInfoRelaychainPresenter: StartStakingInfoBasePresenter {
    let interactor: StartStakingInfoRelaychainInteractorInputProtocol
    let applicationConfig: ApplicationConfigProtocol

    private var minNominatorBond: LoadableViewModelState<BigUInt?> = .loading
    private var bagListSize: LoadableViewModelState<UInt32?> = .loading
    private var networkInfo: LoadableViewModelState<NetworkStakingInfo?> = .loading
    private var eraCountdown: LoadableViewModelState<EraCountdown?> = .loading
    private var maxApy: Decimal?

    init(
        interactor: StartStakingInfoRelaychainInteractorInputProtocol,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol
    ) {
        self.interactor = interactor
        self.applicationConfig = applicationConfig

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            localizationManager: localizationManager
        )
    }

    private func provideViewModel() {
        guard
            let enoughMoneyForDirectStaking = enoughMoneyForDirectStaking(),
            let chainAsset = chainAsset,
            let eraDuration = eraDuration(),
            let networkInfo = networkInfo.value,
            let unstakePeriod = networkInfo?.stakingDuration.unlocking,
            let nominationEraValue = nextEraTime(),
            let minStake = minStake(),
            let maxApy = maxApy else {
            return
        }
        let directStakingAmount = enoughMoneyForDirectStaking ? directStakingMinStake() : nil
        let title = startStakingViewModelFactory.earnupModel(
            earnings: maxApy,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        let wikiUrl = startStakingViewModelFactory.wikiModel(
            url: applicationConfig.novaWikiURL,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
        let termsUrl = startStakingViewModelFactory.termsModel(
            url: applicationConfig.termsURL,
            locale: selectedLocale
        )
        let testnetModel = chainAsset.chain.isTestnet ? startStakingViewModelFactory.testNetworkModel(
            chain: chainAsset.chain,
            locale: selectedLocale
        ) : nil

        let govModel = chainAsset.chain.hasGovernance ? startStakingViewModelFactory.govModel(
            amount: directStakingAmount,
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
                amount: directStakingAmount,
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

        return eraCountdown.timeIntervalTillStart(targetEra: eraCountdown.currentEra + 1)
    }

    private func eraDuration() -> TimeInterval? {
        guard let eraCountdownResult = eraCountdown.value else {
            return nil
        }

        return eraCountdownResult?.eraTimeInterval
    }

    private func enoughMoneyForDirectStaking() -> Bool? {
        guard let balanceState = balanceState else {
            return nil
        }
        guard let minStake = directStakingMinStake() else {
            return nil
        }

        switch balanceState {
        case let .assetBalance(assetBalance):
            return assetBalance.freeInPlank >= minStake
        case .noAccount:
            return false
        }
    }

    private func directStakingMinStake() -> BigUInt? {
        // TODO: add nomination pool min staking
        minStake()
    }

    override func setup() {
        super.setup()
        view?.didReceive(viewModel: .loading)
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

    func didReceive(error: RelaychainStartStakingInfoError) {
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
        maxApy = calculator.calculateMaxEarnings(amount: 1, isCompound: true, period: .year)
    }
}
