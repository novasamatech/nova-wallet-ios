import Foundation
import Foundation_iOS

final class StartStakingInfoSubtensorPresenter: StartStakingInfoBasePresenter {
    let subtensorWireframe: StartStakingInfoSubtensorWireframeProtocol
    let subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol

    private var walletType: MetaAccountModelType?
    private var isHeadlineResolved = false
    private var headlineRate: Decimal?

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
        walletType = wallet.type

        super.didReceive(wallet: wallet, chainAccountId: chainAccountId)
    }

    override func didReceiveStakingEnabled() {}

    override func startStaking() {
        guard let view, let walletType, let accountExistense else {
            return
        }

        if
            case .assetBalance = accountExistense,
            case let .signerNotSupported(type) = SubtensorOperationGate.verdict(for: walletType) {
            subtensorWireframe.presentSignerNotSupportedView(from: view, type: type) {}
            return
        }

        super.startStaking()
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorPresenterProtocol {
    func refreshContent() {
        provideSubtensorViewModel()
        provideBalanceModel()
    }
}

private extension StartStakingInfoSubtensorPresenter {
    func provideSubtensorViewModel() {
        let title = isHeadlineResolved ? createTitle(locale: selectedLocale) : nil

        let viewModel = subtensorViewModelFactory.createViewModel(
            title: title,
            locale: selectedLocale
        )

        (view as? StartStakingInfoSubtensorViewProtocol)?.didReceive(subtensorViewModel: viewModel)
    }

    func createTitle(locale: Locale) -> AccentTextModel {
        guard let headlineRate else {
            let symbol = chainAsset.asset.displayInfo.symbol

            return AccentTextModel(
                text: R.string(preferredLanguages: locale.rLanguages).localizable.stakingStakeFormat(symbol),
                accents: [symbol]
            )
        }

        return startStakingViewModelFactory.earnupModel(
            earnings: headlineRate,
            chainAsset: chainAsset,
            locale: locale
        )
    }
}

extension StartStakingInfoSubtensorPresenter: StartStakingInfoSubtensorInteractorOutputProtocol {
    func didReceive(headlineRate: Decimal?) {
        self.headlineRate = headlineRate
        isHeadlineResolved = true

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
