import Foundation
import SoraFoundation
import BigInt

final class StakingTypePresenter {
    weak var view: StakingTypeViewProtocol?
    weak var delegate: StakingTypeDelegate?

    let wireframe: StakingTypeWireframeProtocol
    let interactor: StakingTypeInteractorInputProtocol
    let viewModelFactory: StakingTypeViewModelFactoryProtocol
    let chainAsset: ChainAsset

    private var nominationPoolRestrictions: RelaychainStakingRestrictions?
    private var directStakingRestrictions: RelaychainStakingRestrictions?
    private var assetBalance: AssetBalance?
    private var directStakingAvailable: Bool = false
    private var method: StakingSelectionMethod?
    private var selection: StakingTypeSelection?

    init(
        interactor: StakingTypeInteractorInputProtocol,
        wireframe: StakingTypeWireframeProtocol,
        chainAsset: ChainAsset,
        initialMethod: StakingSelectionMethod,
        viewModelFactory: StakingTypeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        delegate: StakingTypeDelegate?
    ) {
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        method = initialMethod
        self.localizationManager = localizationManager
    }

    private func updateDirectStakingAvailable() {
        guard let restrictions = directStakingRestrictions, let assetBalance = assetBalance else {
            return
        }
        directStakingAvailable = assetBalance.freeInPlank > restrictions.minRewardableStake ?? 0
    }

    private func provideDirectStakingViewModel() {
        guard let restrictions = directStakingRestrictions else {
            return
        }
        let viewModel = viewModelFactory.directStakingViewModel(
            minStake: restrictions.minRewardableStake,
            chainAsset: chainAsset,
            method: method,
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
            method: method,
            locale: selectedLocale
        )

        view?.didReceivePoolBanner(viewModel: viewModel)
    }

    private func updateView() {
        provideDirectStakingViewModel()
        provideNominationPoolViewModel()
        provideStakingSelection()
    }

    private func provideStakingSelection() {
        switch method?.selectedStakingOption {
        case .direct:
            view?.didReceive(stakingTypeSelection: .direct)
        case .pool:
            view?.didReceive(stakingTypeSelection: .nominationPool)
        case .none: break
        }
    }

    private func showDirectStakingNotAvailableAlert(minStake: String) {
        let languages = selectedLocale.rLanguages
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
}

extension StakingTypePresenter: StakingTypePresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func selectValidators() {
        // TODO:
    }

    func selectNominationPool() {
        // TODO:
    }

    func change(stakingTypeSelection: StakingTypeSelection) {
        guard let restrictions = directStakingRestrictions else {
            return
        }
        switch stakingTypeSelection {
        case .direct:
            if directStakingAvailable {
                view?.didReceive(stakingTypeSelection: .direct)
                method = nil
                provideNominationPoolViewModel()
                selection = .direct
            } else {
                let minStake = viewModelFactory.minStake(
                    minStake: restrictions.minRewardableStake,
                    chainAsset: chainAsset,
                    locale: selectedLocale
                )
                showDirectStakingNotAvailableAlert(minStake: minStake)
                return
            }
        case .nominationPool:
            view?.didReceive(stakingTypeSelection: .nominationPool)
            method = nil
            provideDirectStakingViewModel()
            selection = .nominationPool
        }

        selection.map(interactor.change)
    }

    func save() {
        guard let method = method else {
            return
        }
        delegate?.changeStakingType(method: method)
        wireframe.complete(from: view)
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

    func didReceive(method: StakingSelectionMethod) {
        self.method = method
        updateView()
        view?.didReceiveSaveChangesState(available: true)
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        updateDirectStakingAvailable()
        provideDirectStakingViewModel()
    }

    func didReceive(error: StakingTypeError) {
        switch error {
        case .restrictions, .balance:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .recommendation:
            guard let selection = selection else {
                return
            }
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.change(stakingTypeSelection: selection)
            }
        }
    }
}

extension StakingTypePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
