import Foundation
import Foundation_iOS
import Operation_iOS

final class SelectValidatorsStartPresenter {
    weak var view: SelectValidatorsStartViewProtocol?
    let wireframe: SelectValidatorsStartWireframeProtocol
    let interactor: SelectValidatorsStartInteractorInputProtocol
    let applicationConfig: ApplicationConfigProtocol
    let localizationManager: LocalizationManagerProtocol

    let initialTargets: [SelectedValidatorInfo]?
    let existingStashAddress: AccountAddress?
    let logger: LoggerProtocol?

    private var electedAndPrefValidators: ElectedAndPrefValidators?
    private var electedValidators: [AccountAddress: ElectedValidatorInfo]?
    private var recommendedValidators: [SelectedValidatorInfo]?
    private var selectedValidators: SharedList<SelectedValidatorInfo>?
    private var maxNominations: Int?
    private var hasIdentity: Bool?

    init(
        interactor: SelectValidatorsStartInteractorInputProtocol,
        wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
        initialTargets: [SelectedValidatorInfo]?,
        applicationConfig: ApplicationConfigProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.existingStashAddress = existingStashAddress
        self.initialTargets = initialTargets
        self.applicationConfig = applicationConfig
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func updateSelectedValidatorsIfNeeded() {
        guard
            let electedValidators = electedValidators,
            let maxNominations = maxNominations,
            selectedValidators == nil else {
            return
        }

        let selectedValidatorList = initialTargets?.map { target in
            electedValidators[target.address]?.toSelected(for: existingStashAddress) ?? target
        }
        .sorted { $0.stakeReturn > $1.stakeReturn }
        .prefix(maxNominations) ?? []

        selectedValidators = SharedList(items: selectedValidatorList)
    }

    private func updateRecommendedValidators() {
        guard
            let electedAndPrefValidators = electedAndPrefValidators,
            let maxNominations = maxNominations else {
            return
        }

        let resultLimit = min(electedAndPrefValidators.notExcludedElectedValidators.count, maxNominations)
        let recomendedValidators = RecommendationsComposer(
            resultSize: resultLimit,
            clusterSizeLimit: StakingConstants.targetsClusterLimit
        ).compose(
            from: electedAndPrefValidators.notExcludedElectedToSelectedValidators(for: existingStashAddress),
            preferrences: electedAndPrefValidators.preferredValidators
        )

        recommendedValidators = recomendedValidators
    }

    private func updateView() {
        guard
            let maxNominations = maxNominations,
            let selectedValidators = selectedValidators else {
            return
        }

        let viewModel = SelectValidatorsStartViewModel(
            selectedCount: selectedValidators.count,
            totalCount: maxNominations
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func handle(error: Error) {
        logger?.error("Did receive error \(error)")

        let locale = localizationManager.selectedLocale
        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(
                error: BaseOperationError.unexpectedDependentResult,
                from: view,
                locale: locale
            )
        }
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func updateOnAppearance() {
        updateView()
    }

    func selectRecommendedValidators() {
        guard
            let recommendedValidators = recommendedValidators,
            let maxNominations = maxNominations else {
            return
        }

        wireframe.proceedToRecommendedList(
            from: view,
            validatorList: recommendedValidators,
            maxTargets: maxNominations
        )
    }

    func selectCustomValidators() {
        guard
            let electedAndPrefValidators = electedAndPrefValidators,
            let maxNominations = maxNominations,
            let hasIdentity = hasIdentity,
            let selectedValidators = selectedValidators else {
            return
        }

        let customValidatorList = CustomValidatorsFullList(
            allValidators: electedAndPrefValidators.allElectedToSelectedValidators(for: existingStashAddress),
            preferredValidators: electedAndPrefValidators.preferredValidators
        )

        let recommendedValidatorList = recommendedValidators ?? []

        let groups = SelectionValidatorGroups(
            fullValidatorList: customValidatorList,
            recommendedValidatorList: recommendedValidatorList
        )

        let selectionParams = ValidatorsSelectionParams(
            maxNominations: maxNominations,
            hasIdentity: hasIdentity
        )

        wireframe.proceedToCustomList(
            from: view,
            selectionValidatorGroups: groups,
            selectedValidatorList: selectedValidators,
            validatorsSelectionParams: selectionParams
        )
    }

    func selectLearnMore() {
        guard let view = view else {
            return
        }

        wireframe.showWeb(
            url: applicationConfig.learnRecommendedValidatorsURL,
            from: view,
            style: .automatic
        )
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartInteractorOutputProtocol {
    func didReceiveValidators(result: Result<ElectedAndPrefValidators, Error>) {
        switch result {
        case let .success(validators):
            electedAndPrefValidators = validators

            electedValidators = validators.allElectedValidators.reduce(
                into: [AccountAddress: ElectedValidatorInfo]()
            ) { dict, validator in
                dict[validator.address] = validator
            }

            hasIdentity = validators.allElectedValidators.contains { $0.hasIdentity }

            updateRecommendedValidators()
            updateSelectedValidatorsIfNeeded()
            updateView()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMaxNominations(result: Result<UInt32, Error>) {
        switch result {
        case let .success(maxNominations):
            self.maxNominations = Int(maxNominations)

            updateRecommendedValidators()
            updateSelectedValidatorsIfNeeded()
            updateView()
        case let .failure(error):
            handle(error: error)
        }
    }
}
