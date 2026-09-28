import Foundation
import Foundation_iOS

enum SubtensorValidatorSelectViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        target: SubtensorStakeTarget,
        delegate: SubtensorSubnetSelectDelegate
    ) -> SubtensorValidatorSelectViewProtocol? {
        let interactor = SubtensorValidatorSelectInteractor(
            directoryService: state.earnServices.validatorDirectoryService,
            yieldService: state.earnServices.yieldService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
        let presenter = SubtensorValidatorSelectPresenter(
            target: target,
            chainAsset: state.stakingOption.chainAsset,
            interactor: interactor,
            wireframe: SubtensorValidatorSelectWireframe(),
            delegate: delegate,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
        let view = SubtensorValidatorSelectViewController(
            presenter: presenter,
            isRoot: target.isRoot,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        interactor.presenter = presenter
        return view
    }
}
