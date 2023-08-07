import Foundation
import SoraFoundation
import BigInt

final class StakingTypePresenter {
    weak var view: StakingTypeViewProtocol?
    let wireframe: StakingTypeWireframeProtocol
    let interactor: StakingTypeInteractorInputProtocol
    let viewModelFactory: StakingTypeViewModelFactoryProtocol
    private var state: StakingTypeInitialState

    init(
        interactor: StakingTypeInteractorInputProtocol,
        wireframe: StakingTypeWireframeProtocol,
        chainAsset: ChainAsset,
        viewModelFactory: StakingTypeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        state = StakingTypeInitialState(
            chainAsset: chainAsset,
            directStaking: .recommended(maxCount: 20),
            directStakingMinStake: 410,
            nominationPoolStaking: .init(
                name: "Nova",
                icon: StaticImageViewModel(image: R.image.iconNova()!),
                recommended: true
            ),
            nominationPoolMinStake: 10,
            selection: .direct,
            isDirectStakingAvailable: false
        )
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideDirectStakingViewModel() {
        let viewModel = viewModelFactory.directStakingViewModel(
            minStake: state.directStakingMinStake,
            chainAsset: state.chainAsset,
            choice: state.directStaking,
            locale: selectedLocale
        )
        view?.didReceiveDirectStakingBanner(viewModel: viewModel, available: state.isDirectStakingAvailable)
    }

    private func provideNominationPoolViewModel() {
        let viewModel = viewModelFactory.nominationPoolViewModel(
            minStake: state.nominationPoolMinStake,
            chainAsset: state.chainAsset,
            choice: state.nominationPoolStaking,
            locale: selectedLocale
        )

        view?.didReceivePoolBanner(viewModel: viewModel)
    }

    private func updateView() {
        provideDirectStakingViewModel()
        provideNominationPoolViewModel()
    }
}

struct StakingTypeInitialState {
    let chainAsset: ChainAsset
    let directStaking: ValidatorChoice
    let directStakingMinStake: BigUInt
    let nominationPoolStaking: PoolChoice
    let nominationPoolMinStake: BigUInt
    let selection: StakingTypeSelection
    let isDirectStakingAvailable: Bool
}

enum StakingTypeSelection {
    case direct
    case nominationPool
}

extension StakingTypePresenter: StakingTypePresenterProtocol {
    func setup() {
        updateView()
        view?.didReceive(stakingTypeSelection: state.selection)
    }

    func selectNominators() {
        // TODO:
        view?.didReceive(stakingTypeSelection: .direct)
    }

    func selectNominationPool() {
        // TODO:
        view?.didReceive(stakingTypeSelection: .nominationPool)
    }

    func change(stakingTypeSelection: StakingTypeSelection) {
        switch stakingTypeSelection {
        case .direct:
            if state.isDirectStakingAvailable {
                view?.didReceive(stakingTypeSelection: .direct)
            } else {
                let languages = selectedLocale.rLanguages
                let minStake = viewModelFactory.minStake(
                    minStake: state.directStakingMinStake,
                    chainAsset: state.chainAsset,
                    locale: selectedLocale
                )
                wireframe.present(
                    message: R.string.localizable.stakingTypeDirectStakingAlertMessage(
                        minStake,
                        preferredLanguages: languages
                    ),
                    title: R.string.localizable.stakingTypeDirectStakingAlertTitle(preferredLanguages: languages),
                    closeAction: R.string.localizable.commonBack(preferredLanguages: languages),
                    from: view
                )
            }
        case .nominationPool:
            view?.didReceive(stakingTypeSelection: .nominationPool)
        }
    }
}

extension StakingTypePresenter: StakingTypeInteractorOutputProtocol {}

extension StakingTypePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
