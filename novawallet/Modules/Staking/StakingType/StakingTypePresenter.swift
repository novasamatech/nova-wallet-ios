import Foundation
import Foundation_iOS
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
    private var initialMethod: StakingSelectionMethod
    private var selection: StakingTypeSelection

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
        self.initialMethod = initialMethod
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
        provideSaveChangesState()
    }

    private func provideSaveChangesState() {
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
        let cancelActionTitle = R.string(preferredLanguages: languages).localizable.commonBack()
        let cancelAction = AlertPresentableAction(title: cancelActionTitle, style: .cancel) { [weak self] in
            self?.wireframe.complete(from: self?.view)
        }

        let directStaking = R.string(preferredLanguages: languages).localizable.stakingTypeDirect()

        let viewModel = AlertPresentableViewModel(
            title: R.string(preferredLanguages: languages).localizable.stakingTypeDirectStakingAlertTitle(),
            message: R.string(preferredLanguages: languages
            ).localizable.stakingTypeDirectStakingAlertMessage(minStake, directStaking),
            actions: [cancelAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    private func showSaveChangesAlert() {
        let languages = selectedLocale.rLanguages
        let closeActionTitle = R.string(preferredLanguages: languages).localizable.commonClose()
        let cancelActionTitle = R.string(preferredLanguages: languages).localizable.commonCancel()
        let closeAction = AlertPresentableAction(title: closeActionTitle, style: .destructive) { [weak self] in
            self?.wireframe.complete(from: self?.view)
        }

        let viewModel = AlertPresentableViewModel(
            title: nil,
            message: R.string(preferredLanguages: languages).localizable.commonCloseWhenChangesConfirmation(),
            actions: [closeAction],
            closeAction: cancelActionTitle
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }

    private func presentAlreadyStakingAlert(for type: StakingTypeSelection) {
        let backAction = AlertPresentableAction(
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonBack(),
            style: .normal
        ) { [weak self] in
            self?.wireframe.complete(from: self?.view)
        }

        let message: String

        switch type {
        case .direct:
            message = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingStartAlreadyStakingDirect()
        case .nominationPool:
            message = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingStartAlreadyStakingPool()
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingStartAlreadyStakingTitle(),
            message: message,
            actions: [backAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    private var hasChanges: Bool {
        initialMethod.selectedStakingOption != method?.selectedStakingOption
    }
}

extension StakingTypePresenter: StakingTypePresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func selectValidators() {
        guard let method = method, case let .direct(validators) = method.selectedStakingOption else {
            return
        }

        let fullValidatorList = CustomValidatorsFullList(
            allValidators: validators.electedAndPrefValidators.allElectedToSelectedValidators(),
            preferredValidators: validators.electedAndPrefValidators.preferredValidators
        )

        let recommendedValidatorList = validators.recommendedValidators

        let groups = SelectionValidatorGroups(
            fullValidatorList: fullValidatorList,
            recommendedValidatorList: recommendedValidatorList
        )

        let hasIdentity = fullValidatorList.allValidators.contains { $0.hasIdentity }
        let selectionParams = ValidatorsSelectionParams(
            maxNominations: validators.maxTargets,
            hasIdentity: hasIdentity
        )

        let delegateFacade = StakingSetupTypeEntityFacade(
            selectedMethod: method,
            delegate: delegate
        )

        wireframe.showValidators(
            from: view,
            selectionValidatorGroups: groups,
            selectedValidatorList: SharedList(items: validators.targets),
            validatorsSelectionParams: selectionParams,
            delegate: delegateFacade
        )
    }

    func selectNominationPool() {
        guard let method = method, case let .pool(selectedPool) = method.selectedStakingOption else {
            return
        }

        let delegateFacade = StakingSetupTypeEntityFacade(
            selectedMethod: method,
            delegate: delegate
        )

        wireframe.showNominationPoolsList(
            from: view,
            amount: amount,
            delegate: delegateFacade,
            selectedPool: selectedPool
        )
    }

    func change(stakingTypeSelection: StakingTypeSelection) {
        guard canChangeType else {
            presentAlreadyStakingAlert(for: stakingTypeSelection)
            return
        }

        guard let restrictions = directStakingRestrictions else {
            return
        }

        switch stakingTypeSelection {
        case .direct:
            if directStakingAvailable {
                selection = .direct
                method = nil

                provideStakingSelection()
                provideNominationPoolViewModel()
                provideSaveChangesState()
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
            provideSaveChangesState()
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
        if hasChanges, method != nil {
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
