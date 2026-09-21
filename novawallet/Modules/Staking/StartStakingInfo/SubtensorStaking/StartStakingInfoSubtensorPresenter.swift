import BigInt
import Foundation
import Foundation_iOS

final class StartStakingInfoSubtensorPresenter: StartStakingInfoBasePresenter {
    let subtensorWireframe: StartStakingInfoSubtensorWireframeProtocol
    let subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol

    private var walletType: MetaAccountModelType?
    private var strategies: [SubtensorStakingStrategy] = []

    private var state: State {
        didSet {
            if state != oldValue {
                provideViewModel(state: state)
            }
        }
    }

    init(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoSubtensorInteractorInputProtocol,
        wireframe: StartStakingInfoSubtensorWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol,
        subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        subtensorWireframe = wireframe
        self.subtensorViewModelFactory = subtensorViewModelFactory
        state = .init(chainAsset: chainAsset, networkInfo: nil)

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
        (view as? StartStakingInfoSubtensorViewProtocol)?.didReceive(subtensorViewModel: .loading)
    }

    override func didReceive(wallet: MetaAccountModel, chainAccountId: AccountId?) {
        walletType = wallet.type

        super.didReceive(wallet: wallet, chainAccountId: chainAccountId)
    }

    override func startStaking() {
        guard let view, let walletType else {
            return
        }

        switch SubtensorOperationGate.verdict(for: walletType) {
        case .allowed:
            subtensorWireframe.showStrategies(from: view)
        case let .signerNotSupported(type):
            subtensorWireframe.presentSignerNotSupportedView(from: view, type: type) {}
        case .noSigning:
            subtensorWireframe.presentNoSigningView(from: view) {}
        }
    }

    override func provideViewModel(state: StartStakingStateProtocol) {
        super.provideViewModel(state: state)
        provideSubtensorViewModel()
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorPresenterProtocol {
    func chooseManually() {
        super.startStaking()
    }

    func refreshContent() {
        provideSubtensorViewModel()
        provideBalanceModel()
    }
}

private extension StartStakingInfoSubtensorPresenter {
    func provideSubtensorViewModel() {
        guard !strategies.isEmpty else {
            return
        }

        let viewModel = subtensorViewModelFactory.createViewModel(
            from: strategies,
            locale: selectedLocale
        )

        (view as? StartStakingInfoSubtensorViewProtocol)?.didReceive(
            subtensorViewModel: .loaded(value: viewModel)
        )
    }

    func createTitle(for state: StartStakingStateProtocol, locale: Locale) -> AccentTextModel {
        guard let maxApy = state.maxApy else {
            let symbol = chainAsset.asset.displayInfo.symbol

            return AccentTextModel(
                text: R.string(preferredLanguages: locale.rLanguages).localizable.stakingStakeFormat(symbol),
                accents: [symbol]
            )
        }

        return startStakingViewModelFactory.earnupModel(
            earnings: maxApy,
            chainAsset: chainAsset,
            locale: locale
        )
    }

    func createParagraphs(
        for state: StartStakingStateProtocol,
        minStake: BigUInt,
        locale: Locale
    ) -> [ParagraphView.Model] {
        let govModel = state.shouldHaveGovInfo ? startStakingViewModelFactory.govModel(
            amount: state.govThresholdAmount,
            chainAsset: chainAsset,
            locale: locale
        ) : nil

        return [
            self.state.isSafeModeActive ? createSafeModeModel(for: locale) : nil,
            startStakingViewModelFactory.stakeModel(
                minStake: minStake,
                rewardStartDelay: Constants.rootRewardsAccrualEstimate,
                chainAsset: chainAsset,
                locale: locale
            ),
            createUnstakeModel(for: state, locale: locale),
            startStakingViewModelFactory.rewardModel(
                amount: nil,
                chainAsset: chainAsset,
                rewardTimeInterval: Constants.rootRewardsAccrualEstimate,
                destination: .manual,
                locale: locale
            ),
            createClaimRestakeNoteModel(for: locale),
            state.maxApy != nil ? createApyCaveatModel(for: locale) : nil,
            govModel,
            startStakingViewModelFactory.recommendationModel(locale: locale)
        ].compactMap { $0 }
    }

    enum Constants {
        /// root dividends land in the claimable basket roughly every two days on-chain
        static let rootRewardsAccrualEstimate: TimeInterval = 2 * 24 * 3600
    }

    func createUnstakeModel(
        for state: StartStakingStateProtocol,
        locale: Locale
    ) -> ParagraphView.Model {
        guard let unstakingTime = state.unstakingTime, unstakingTime > 0 else {
            return createInstantUnstakeModel(for: locale)
        }

        return startStakingViewModelFactory.unstakeModel(unstakePeriod: unstakingTime, locale: locale)
    }

    func createInstantUnstakeModel(for locale: Locale) -> ParagraphView.Model {
        let text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorHintUnstakeInstant()

        return .init(
            image: R.image.clock(),
            text: AccentTextModel(text: text, accents: [])
        )
    }

    /// spec §4.4 rule 7 asks for a chain-wide notice rather than a per-transaction error, and the
    /// staking main screen only reaches users who already hold a position
    func createSafeModeModel(for locale: Locale) -> ParagraphView.Model {
        let text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorSafeModeMessage()

        return .init(
            image: R.image.iconWarning(),
            text: AccentTextModel(text: text, accents: [])
        )
    }

    func createClaimRestakeNoteModel(for locale: Locale) -> ParagraphView.Model {
        let text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorClaimRestakeNote()

        return .init(
            image: R.image.cup(),
            text: AccentTextModel(text: text, accents: [])
        )
    }

    /// spec §6.2 caveats — only shown alongside a rendered percentage, so the tile never carries
    /// a disclaimer about a number it is not showing
    func createApyCaveatModel(for locale: Locale) -> ParagraphView.Model {
        let text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorApyDeclinesNote()

        return .init(
            image: R.image.iconInfoAccent(),
            text: AccentTextModel(text: text, accents: [])
        )
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorInteractorOutputProtocol {
    func didReceive(networkInfo: SubtensorNetworkInfo) {
        logger.debug("Network info: \(networkInfo)")

        state.networkInfo = networkInfo
    }

    func didReceive(rootAnnualReturn: Decimal?) {
        logger.debug("Root annual return: \(String(describing: rootAnnualReturn))")

        state.rootAnnualReturn = rootAnnualReturn
    }

    func didReceive(strategies: [SubtensorStakingStrategy]) {
        self.strategies = strategies
        provideSubtensorViewModel()
    }

    func didReceiveStrategies(error: Error) {
        logger.error("Strategies request failed: \(error)")

        subtensorWireframe.presentRequestStatus(
            on: view,
            locale: selectedLocale
        ) { [weak self] in
            (self?.baseInteractor as? StartStakingInfoSubtensorInteractorInputProtocol)?.retryStrategies()
        }
    }
}

extension StartStakingInfoSubtensorPresenter {
    struct State: StartStakingStateProtocol, Equatable {
        let chainAsset: ChainAsset
        var networkInfo: SubtensorNetworkInfo?
        var rootAnnualReturn: Decimal?

        var minStake: BigUInt? {
            networkInfo?.minStake
        }

        var rewardTime: TimeInterval? {
            Constants.rootRewardsAccrualEstimate
        }

        var unstakingTime: TimeInterval? {
            networkInfo.map { info in
                let blockTimeMillis = chainAsset.chain.defaultBlockTimeMillis ??
                    SubtensorStakingFlowConstants.blockTimeMillis

                return TimeInterval(info.rootUnlockInterval) * TimeInterval(blockTimeMillis).seconds
            }
        }

        var rewardDelay: TimeInterval? {
            Constants.rootRewardsAccrualEstimate
        }

        /// nil keeps the APY-less tile, which is the fallback the empirical gate of spec §6.2 asks
        /// for whenever the engine cannot produce an honest number
        var maxApy: Decimal? {
            rootAnnualReturn
        }

        var isSafeModeActive: Bool {
            networkInfo?.isSafeModeActive ?? false
        }

        var rewardsAutoPayoutThresholdAmount: BigUInt? {
            nil
        }

        var govThresholdAmount: BigUInt? {
            nil
        }

        var shouldHaveGovInfo: Bool {
            chainAsset.chain.hasGovernance
        }

        var rewardsDestination: DefaultStakingRewardDestination {
            .manual
        }
    }
}
