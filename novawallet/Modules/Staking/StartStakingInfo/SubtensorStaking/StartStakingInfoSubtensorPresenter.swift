import Foundation
import BigInt
import Foundation_iOS

final class StartStakingInfoSubtensorPresenter: StartStakingInfoBasePresenter {
    let interactor: StartStakingInfoSubtensorInteractorInputProtocol
    let subtensorWireframe: StartStakingInfoSubtensorWireframeProtocol
    let subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol

    private var wallet: MetaAccountModel?

    private var state = State() {
        didSet {
            provideViewModel(state: state)
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
        self.interactor = interactor
        subtensorWireframe = wireframe
        self.subtensorViewModelFactory = subtensorViewModelFactory

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

    override func createParagraphs(for _: StartStakingStateProtocol) -> [ParagraphView.Model]? {
        subtensorViewModelFactory.createParagraphs(locale: selectedLocale)
    }

    override func didReceive(wallet: MetaAccountModel, chainAccountId: AccountId?) {
        self.wallet = wallet

        super.didReceive(wallet: wallet, chainAccountId: chainAccountId)
    }

    override func didReceiveStakingEnabled() {}

    override func startStaking() {
        startStakingWithGate { [weak self] in self?.subtensorWireframe.showSetupAmount(from: self?.view) }
    }

    override func selectSecondaryAction() {
        startStakingWithGate { [weak self] in self?.subtensorWireframe.showAllOptions(from: self?.view) }
    }

    func startStakingWithGate(continuation: @escaping () -> Void) {
        guard let view, let wallet, let accountExistense else { return }

        guard case .assetBalance = accountExistense else {
            super.startStaking(continuation: continuation)
            return
        }

        subtensorWireframe.checkingSubtensorSigning(for: wallet, chain: chainAsset.chain, from: view) { [weak self] in
            self?.proceedStaking(continuation: continuation)
        }
    }

    private func proceedStaking(continuation: () -> Void) {
        super.startStaking(continuation: continuation)
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorInteractorOutputProtocol {
    func didReceive(maxApy: Decimal) {
        state.maxApy = maxApy
    }

    func didReceive(error: SubtensorStartStakingInfoError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .maxApy:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryMaxApy()
            }
        }
    }

    func didReceiveAccountChange() {
        subtensorWireframe.close(from: view)
    }
}

extension StartStakingInfoSubtensorPresenter: SubtensorSubnetSelectDelegate {
    func didSelectStakeTarget(_ target: SubtensorStakeTarget, validator: SubtensorValidatorDirectoryItem?) {
        if target.isRoot {
            subtensorWireframe.showRootDetails(from: view)
        } else {
            subtensorWireframe.showSubnetSetup(from: view, target: target, validator: validator)
        }
    }
}

extension StartStakingInfoSubtensorPresenter {
    struct State: StartStakingStateProtocol {
        var maxApy: Decimal?

        var minStake: BigUInt? { nil }
        var rewardTime: TimeInterval? { nil }
        var unstakingTime: TimeInterval? { nil }
        var rewardDelay: TimeInterval? { nil }
        var rewardsAutoPayoutThresholdAmount: BigUInt? { nil }
        var govThresholdAmount: BigUInt? { nil }
        var shouldHaveGovInfo: Bool { false }
        var rewardsDestination: DefaultStakingRewardDestination { .manual }
    }
}
