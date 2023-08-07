import Foundation
import SoraFoundation
import BigInt

final class StakingTypePresenter {
    weak var view: StakingTypeViewProtocol?
    let wireframe: StakingTypeWireframeProtocol
    let interactor: StakingTypeInteractorInputProtocol
    let viewModelFactory: StakingTypeViewModelFactoryProtocol
    let chainAsset: ChainAsset
    private var nominationPoolRestrictions: RelaychainStakingRestrictions?
    private var directStakingRestrictions: RelaychainStakingRestrictions?
    private var assetBalance: AssetBalance?
    private var directStakingAvailable: Bool = false

    init(
        interactor: StakingTypeInteractorInputProtocol,
        wireframe: StakingTypeWireframeProtocol,
        chainAsset: ChainAsset,
        viewModelFactory: StakingTypeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func updateDirectStakingAvailable() {
        guard let restrictions = directStakingRestrictions, let assetBalance = assetBalance else {
            return
        }
        directStakingAvailable = assetBalance.freeInPlank > restrictions.minRewardableStake ?? 0
    }

    private func provideDirectStakingViewModel() {
        guard let restrictions = directStakingRestrictions, let assetBalance = assetBalance else {
            return
        }
        let viewModel = viewModelFactory.directStakingViewModel(
            minStake: restrictions.minRewardableStake,
            chainAsset: chainAsset,
            choice: nil,
            locale: selectedLocale
        )

        view?.didReceiveDirectStakingBanner(viewModel: viewModel, available: directStakingAvailable)
    }

    private func provideNominationPoolViewModel() {
        guard let restrictions = nominationPoolRestrictions else {
            return
        }
        let viewModel = viewModelFactory.nominationPoolViewModel(
            minStake: restrictions.minRewardableStake,
            chainAsset: chainAsset,
            choice: nil,
            locale: selectedLocale
        )

        view?.didReceivePoolBanner(viewModel: viewModel)
    }

    private func updateView() {
        provideDirectStakingViewModel()
        provideNominationPoolViewModel()
    }
}

enum StakingTypeSelection {
    case direct
    case nominationPool
}

extension StakingTypePresenter: StakingTypePresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
        view?.didReceive(stakingTypeSelection: .direct)
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
        guard let restrictions = directStakingRestrictions else {
            return
        }
        switch stakingTypeSelection {
        case .direct:
            if directStakingAvailable {
                view?.didReceive(stakingTypeSelection: .direct)
            } else {
                let languages = selectedLocale.rLanguages
                let minStake = viewModelFactory.minStake(
                    minStake: restrictions.minRewardableStake,
                    chainAsset: chainAsset,
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

extension StakingTypePresenter: StakingTypeInteractorOutputProtocol {
    func didReceive(nominationPoolRestrictions: RelaychainStakingRestrictions) {
        self.nominationPoolRestrictions = nominationPoolRestrictions
        provideNominationPoolViewModel()
    }

    func didReceive(directStakingRestrictions: RelaychainStakingRestrictions) {
        self.directStakingRestrictions = directStakingRestrictions
        updateDirectStakingAvailable()
        provideDirectStakingViewModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        updateDirectStakingAvailable()
        provideDirectStakingViewModel()
    }
}

extension StakingTypePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
