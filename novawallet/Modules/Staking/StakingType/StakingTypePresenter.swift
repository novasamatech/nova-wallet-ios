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
    private var recommendedValidators: PreparedValidators?

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
            method: recommendedValidators != nil ? method : nil,
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
        guard case let .direct(validators) = method?.selectedStakingOption,
              let recommendedValidators = recommendedValidators else {
            return
        }

        let electedValidatorList = validators.electedValidators.map { $0.toSelected(for: nil) }
        let recommendedValidatorList = recommendedValidators.targets.map {
            $0.toSelected(for: nil)
        } ?? []
        let selectedValidators = validators.targets.map {
            $0.toSelected(for: nil)
        }
        let groups = SelectionValidatorGroups(
            fullValidatorList: electedValidatorList,
            recommendedValidatorList: recommendedValidatorList
        )

        let hasIdentity = validators.targets.contains { $0.hasIdentity }
        let selectionParams = ValidatorsSelectionParams(
            maxNominations: validators.maxTargets,
            hasIdentity: hasIdentity
        )

        wireframe.showValidators(
            from: view,
            selectionValidatorGroups: groups,
            selectedValidatorList: SharedList(items: selectedValidators),
            validatorsSelectionParams: selectionParams,
            delegate: self
        )
    }

    func selectNominationPool() {
        guard case let .pool(selectedPool) = method?.selectedStakingOption else {
            return
        }
        wireframe.showNominationPoolsList(
            from: view,
            amount: amount,
            delegate: self,
            selectedPool: selectedPool
        )
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

    func didReceive(recommendedValidators: PreparedValidators) {
        self.recommendedValidators = recommendedValidators
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

extension StakingTypePresenter: StakingSelectPoolDelegate {
    func changePoolSelection(selectedPool: NominationPools.SelectedPool, isRecommended: Bool) {
        guard let restrictions = nominationPoolRestrictions else {
            return
        }

        hasChanges = true
        method = .manual(.init(
            staking: .pool(selectedPool),
            restrictions: restrictions,
            usedRecommendation: isRecommended
        ))

        updateView()
    }
}

extension StakingTypePresenter: StakingSelectValidatorsDelegate {
    func changeValidatorsSelection(validatorList: [SelectedValidatorInfo], maxTargets: Int) {
        guard let recommendedValidators = recommendedValidators,
              case let .direct(validators) = method?.selectedStakingOption,
              let restrictions = method?.restrictions else {
            return
        }
        let selectedAddresses = validatorList.map(\.address)
        let selectedValidators = validators.electedValidators.filter {
            selectedAddresses.contains($0.address)
        }
        let usedRecommendation = Set(selectedAddresses) == Set(recommendedValidators.targets.map(\.address))
        hasChanges = true
        method = .manual(.init(
            staking: .direct(.init(
                targets: selectedValidators,
                maxTargets: maxTargets,
                electedValidators: validators.electedValidators
            )),
            restrictions: restrictions,
            usedRecommendation: usedRecommendation
        ))

        updateView()
    }
}
