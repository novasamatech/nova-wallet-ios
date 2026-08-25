import BigInt
import Foundation
import Foundation_iOS

final class StartStakingInfoSubtensorPresenter: StartStakingInfoBasePresenter {
    let subtensorWireframe: StartStakingInfoSubtensorWireframeProtocol

    private var walletType: MetaAccountModelType?

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
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        subtensorWireframe = wireframe
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
        view?.didReceive(viewModel: .loading)
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
            super.startStaking()
        case let .signerNotSupported(type):
            subtensorWireframe.presentSignerNotSupportedView(from: view, type: type) {}
        case .noSigning:
            subtensorWireframe.presentNoSigningView(from: view) {}
        }
    }

    override func provideViewModel(state: StartStakingStateProtocol) {
        super.provideViewModel(state: state)

        guard state.maxApy == nil, let minStake = state.minStake else {
            return
        }

        let locale = selectedLocale
        let symbol = chainAsset.asset.displayInfo.symbol

        let title = AccentTextModel(
            text: R.string(preferredLanguages: locale.rLanguages).localizable.stakingStakeFormat(symbol),
            accents: [symbol]
        )

        let wikiUrl = startStakingViewModelFactory.wikiModel(
            url: chainAsset.chain.stakingWiki ?? applicationConfig.websiteURL,
            chainAsset: chainAsset,
            locale: locale
        )

        let termsUrl = startStakingViewModelFactory.termsModel(
            url: applicationConfig.termsURL,
            locale: locale
        )

        let govModel = state.shouldHaveGovInfo ? startStakingViewModelFactory.govModel(
            amount: state.govThresholdAmount,
            chainAsset: chainAsset,
            locale: locale
        ) : nil

        let paragraphs = [
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
            govModel,
            startStakingViewModelFactory.recommendationModel(locale: locale)
        ].compactMap { $0 }

        let model = StartStakingViewModel(
            title: title,
            paragraphs: paragraphs,
            wikiUrl: wikiUrl,
            termsUrl: termsUrl
        )

        view?.didReceive(viewModel: .loaded(value: model))
    }
}

private extension StartStakingInfoSubtensorPresenter {
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

    func createClaimRestakeNoteModel(for locale: Locale) -> ParagraphView.Model {
        let text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorClaimRestakeNote()

        return .init(
            image: R.image.cup(),
            text: AccentTextModel(text: text, accents: [])
        )
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorInteractorOutputProtocol {
    func didReceive(networkInfo: SubtensorNetworkInfo) {
        logger.debug("Network info: \(networkInfo)")

        state.networkInfo = networkInfo
    }
}

extension StartStakingInfoSubtensorPresenter {
    struct State: StartStakingStateProtocol, Equatable {
        let chainAsset: ChainAsset
        var networkInfo: SubtensorNetworkInfo?

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

        var maxApy: Decimal? {
            nil
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
