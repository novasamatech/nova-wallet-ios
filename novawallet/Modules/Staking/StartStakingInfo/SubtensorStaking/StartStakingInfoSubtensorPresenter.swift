import Foundation
import Foundation_iOS

final class StartStakingInfoSubtensorPresenter: StartStakingInfoBasePresenter {
    let subtensorWireframe: StartStakingInfoSubtensorWireframeProtocol
    let subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol

    private var wallet: MetaAccountModel?
    private var headlineRate: Decimal?

    init(
        chainAsset: ChainAsset,
        interactor: StartStakingInfoInteractorInputProtocol,
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
        provideSubtensorViewModel()
    }

    override func didReceive(wallet: MetaAccountModel, chainAccountId: AccountId?) {
        self.wallet = wallet

        super.didReceive(wallet: wallet, chainAccountId: chainAccountId)
    }

    override func didReceiveStakingEnabled() {}

    override func startStaking() {
        startStakingWithGate { [weak self] in self?.subtensorWireframe.showSetupAmount(from: self?.view) }
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

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorPresenterProtocol {
    func seeAllOptions() {
        startStakingWithGate { [weak self] in self?.subtensorWireframe.showAllOptions(from: self?.view) }
    }

    func refreshContent() {
        provideSubtensorViewModel()
        provideBalanceModel()
    }
}

private extension StartStakingInfoSubtensorPresenter {
    func provideSubtensorViewModel() {
        let viewModel = subtensorViewModelFactory.createViewModel(
            headlineRate: headlineRate,
            symbol: chainAsset.asset.displayInfo.symbol,
            locale: selectedLocale
        )

        (view as? StartStakingInfoSubtensorViewProtocol)?.didReceive(subtensorViewModel: viewModel)
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorInteractorOutputProtocol {
    func didReceive(headlineRate: Decimal?) {
        self.headlineRate = headlineRate

        provideSubtensorViewModel()
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
