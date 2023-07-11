import SoraFoundation
import BigInt

final class StartStakingInfoParachainPresenter: StartStakingInfoBasePresenter {
    let interactor: StartStakingInfoParachainInteractorInputProtocol
    let applicationConfig: ApplicationConfigProtocol

    private var networkInfo: ParachainStaking.NetworkInfo?
    private var roundInfo: ParachainStaking.RoundInfo?
    private var maxApy: Decimal?
    private var blockNumber: BlockNumber?
    private var stakingDuration: ParachainStakingDuration?

    init(
        interactor: StartStakingInfoParachainInteractorInputProtocol,
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

    private func minStake() -> BigUInt? {
        guard let networkInfo = networkInfo else {
            return nil
        }
        return max(networkInfo.minStakeForRewards, networkInfo.minTechStake)
    }

    private func directStakingMinStake() -> BigUInt? {
        minStake()
    }

    private func nextEraStartTime() -> TimeInterval? {
        guard let roundCountdown = roundCountdown() else {
            return nil
        }

        return roundCountdown.timeIntervalTillNextActiveEraStart()
    }

    private func roundCountdown() -> RoundCountdown? {
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

    private func unstakingTime() -> TimeInterval? {
        guard let stakingDuration = stakingDuration else {
            return nil
        }

        return stakingDuration.unstaking
    }

    private func eraDuration() -> TimeInterval? {
        guard let stakingDuration = stakingDuration else {
            return nil
        }

        return stakingDuration.round
    }

    private func provideViewModel() {
        guard
            let enoughMoneyForDirectStaking = enoughMoneyForDirectStaking(),
            let chainAsset = chainAsset,
            let eraDuration = eraDuration(),
            let unstakingTime = unstakingTime(),
            let nextEraStartTime = nextEraStartTime(),
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
                nextEra: nextEraStartTime,
                chainAsset: chainAsset,
                locale: selectedLocale
            ),
            startStakingViewModelFactory.unstakeModel(unstakePeriod: unstakingTime, locale: selectedLocale),
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

    private func enoughMoneyForDirectStaking() -> Bool? {
        guard let balanceState = balanceState else {
            return nil
        }
        guard let minStake = minStake() else {
            return nil
        }

        switch balanceState {
        case let .assetBalance(assetBalance):
            return assetBalance.freeInPlank >= minStake
        case .noAccount:
            return false
        }
    }

    override func setup() {
        super.setup()
        view?.didReceive(viewModel: .loading)
    }
}

extension StartStakingInfoParachainPresenter: StartStakingInfoParachainInteractorOutputProtocol {
    func didReceive(networkInfo: ParachainStaking.NetworkInfo?) {
        self.networkInfo = networkInfo
        provideViewModel()
    }

    func didReceive(error: ParachainStartStakingInfoError) {
        print("StartStakingInfoParachainPresenter.didReceive(error:\(error))")
    }

    func didReceive(parastakingRound roundInfo: ParachainStaking.RoundInfo?) {
        self.roundInfo = roundInfo
        provideViewModel()
    }

    func didReceive(calculator: ParaStakingRewardCalculatorEngineProtocol) {
        maxApy = calculator.calculateMaxEarnings(amount: 1, period: .year)
        provideViewModel()
    }

    func didReceive(blockNumber: BlockNumber?) {
        if self.blockNumber == nil {
            self.blockNumber = blockNumber
            provideViewModel()
        } else {
            self.blockNumber = blockNumber
        }
    }

    func didReceive(stakingDuration: ParachainStakingDuration) {
        self.stakingDuration = stakingDuration
        provideViewModel()
    }
}
