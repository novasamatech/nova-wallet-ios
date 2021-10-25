import SoraFoundation
import SoraKeystore

struct ValidatorListFilterViewFactory {
    static func createView(
        for state: StakingSharedState,
        filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol? {
        guard let assetInfo = state.settings.value?.assetDisplayInfo else {
            return nil
        }

        let wireframe = ValidatorListFilterWireframe()

        let viewModelFactory = ValidatorListFilterViewModelFactory()

        let presenter = ValidatorListFilterPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            assetInfo: assetInfo,
            filter: filter,
            localizationManager: LocalizationManager.shared
        )

        let view = ValidatorListFilterViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.delegate = delegate

        return view
    }
}
