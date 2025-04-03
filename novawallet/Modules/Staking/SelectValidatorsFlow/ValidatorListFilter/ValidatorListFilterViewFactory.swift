import Foundation_iOS
import Keystore_iOS

struct ValidatorListFilterViewFactory {
    static func createView(
        for state: RelaychainStakingSharedStateProtocol,
        filter: CustomValidatorListFilter,
        hasIdentity: Bool,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        return createView(
            chainAsset: chainAsset,
            filter: filter,
            hasIdentity: hasIdentity,
            delegate: delegate
        )
    }

    static func createView(
        chainAsset: ChainAsset,
        filter: CustomValidatorListFilter,
        hasIdentity: Bool,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol? {
        let wireframe = ValidatorListFilterWireframe()

        let viewModelFactory = ValidatorListFilterViewModelFactory()

        let presenter = ValidatorListFilterPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            assetInfo: chainAsset.assetDisplayInfo,
            filter: filter,
            hasIdentity: hasIdentity,
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
