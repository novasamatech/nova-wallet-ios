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
    let canChangeType: Bool
    let amount: BigUInt

    private var nominationPoolRestrictions: RelaychainStakingRestrictions?
    private var directStakingRestrictions: RelaychainStakingRestrictions?
    private var directStakingAvailable: Bool = false
    private var method: StakingSelectionMethod?
    private var selection: StakingTypeSelection
    private var hasChanges: Bool = false

    init(
        interactor: StakingTypeInteractorInputProtocol,
        wireframe: StakingTypeWireframeProtocol,
        chainAsset: ChainAsset,
        amount: BigUInt,
        canChangeType: Bool,
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
        self.amount = amount
        self.canChangeType = canChangeType
        method = initialMethod

        switch initialMethod.selectedStakingOption {
        case .direct:
            selection = .direct
        case .pool, .none:
            selection = .nominationPool
        }

        self.localizationManager = localizationManager
    }

    private func updateDirectStakingAvailable() {
        guard let restrictions = directStakingRestrictions else {
            return
        }

        if let minRewardableStake = restrictions.minRewardableStake {
            directStakingAvailable = amount >= minRewardableStake
        } else if let minJoinStake = restrictions.minJoinStake {
            directStakingAvailable = amount >= minJoinStake
        } else {
            directStakingAvailable = true
        }
    }

    private func provideDirectStakingViewModel() {
        guard let restrictions = directStakingRestrictions else {
            return
        }

        let viewModel = viewModelFactory.directStakingViewModel(
            minStake: restrictions.minRewardableStake ?? restrictions.minJoinStake,
            chainAsset: chainAsset,
            method: method,
            locale: selectedLocale
        )

        let available = selection == .direct || canChangeType && directStakingAvailable

        view?.didReceiveDirectStakingBanner(viewModel: viewModel, available: available)
    }

    private func provideNominationPoolViewModel() {
        guard let restrictions = nominationPoolRestrictions else {
            return
        }

        let viewModel = viewModelFactory.nominationPoolViewModel(
            minStake: restrictions.minRewardableStake ?? restrictions.minJoinStake,
            chainAsset: chainAsset,
            method: method,
            locale: selectedLocale
        )

        let available = selection == .nominationPool || canChangeType

        view?.didReceivePoolBanner(viewModel: viewModel, available: available)
    }

    private func updateView() {
        provideDirectStakingViewModel()
        provideNominationPoolViewModel()
        provideStakingSelection()

        if hasChanges, method != nil {
            view?.didReceiveSaveChangesState(available: true)
        } else {
            view?.didReceiveSaveChangesState(available: false)
        }
    }

    private func provideStakingSelection() {
        view?.didReceive(stakingTypeSelection: selection)
    }

    private func showDirectStakingNotAvailableAlert(minStake: String) {
        let languages = selectedLocale.rLanguages
        let cancelActionTitle = R.string.localizable.commonBack(preferredLanguages: languages)
        let cancelAction = AlertPresentableAction(title: cancelActionTitle, style: .cancel) { [weak self] in
            self?.wireframe.complete(from: self?.view)
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.stakingTypeDirectStakingAlertTitle(preferredLanguages: languages),
            message: R.string.localizable.stakingTypeDirectStakingAlertMessage(
                minStake,
                preferredLanguages: languages
            ),
            actions: [cancelAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    private func showSaveChangesAlert() {
        let languages = selectedLocale.rLanguages
        let saveActionTitle = R.string.localizable.commonSave(preferredLanguages: languages)
        let cancelActionTitle = R.string.localizable.commonCancel(preferredLanguages: languages)
        let saveAction = AlertPresentableAction(title: saveActionTitle) { [weak self] in
            self?.save()
        }
        let cancelAction = AlertPresentableAction(title: cancelActionTitle, style: .cancel) { [weak self] in
            self?.wireframe.complete(from: self?.view)
        }
        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.stakingTypeAlertUnsavedChangesTitle(preferredLanguages: languages),
            message: R.string.localizable.stakingTypeAlertUnsavedChangesMessage(preferredLanguages: languages),
            actions: [saveAction, cancelAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
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
        guard canChangeType, let restrictions = directStakingRestrictions else {
            return
        }

        switch stakingTypeSelection {
        case .direct:
            if directStakingAvailable {
                selection = .direct
                method = nil

                provideStakingSelection()
                provideNominationPoolViewModel()
            } else {
                let minStake = viewModelFactory.minStake(
                    minStake: restrictions.minRewardableStake ?? restrictions.minJoinStake,
                    chainAsset: chainAsset,
                    locale: selectedLocale
                )
                showDirectStakingNotAvailableAlert(minStake: minStake)
                return
            }
        case .nominationPool:
            selection = .nominationPool
            method = nil

            provideStakingSelection()
            provideDirectStakingViewModel()
        }

        interactor.change(stakingTypeSelection: selection)
    }

    func save() {
        guard let method = method else {
            return
        }
        delegate?.changeStakingType(method: method)
        wireframe.complete(from: view)
    }

    func back() {
        if hasChanges {
            showSaveChangesAlert()
        } else {
            wireframe.complete(from: view)
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

    func didReceive(method: StakingSelectionMethod) {
        self.method = method
        hasChanges = true
        updateView()
    }

    func didReceive(error: StakingTypeError) {
        switch error {
        case .restrictions:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .recommendation:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                guard let self = self else {
                    return
                }

                self.interactor.change(stakingTypeSelection: self.selection)
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
