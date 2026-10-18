import Foundation
import Foundation_iOS

enum SubtensorValidatorSelectViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    ) -> SubtensorValidatorSelectViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset
        let earnServices = state.earnServices

        let interactor = SubtensorValidatorSelectInteractor(
            target: target,
            directoryService: earnServices.validatorDirectoryService,
            yieldService: earnServices.yieldService,
            catalogueService: earnServices.catalogueService,
            recommendationService: earnServices.recommendationService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let listFactory = SubtensorValidatorListFactory(
            chainFormat: chainAsset.chain.chainFormat,
            assetDisplayInfo: chainAsset.assetDisplayInfo
        )

        let presenter = SubtensorValidatorSelectPresenter(
            target: target,
            selectedHotkey: selectedHotkey,
            interactor: interactor,
            wireframe: SubtensorValidatorSelectWireframe(state: state),
            listFactory: listFactory,
            delegate: delegate,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SubtensorValidatorSelectViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
