import Foundation
import Foundation_iOS
import UIKit

enum SubtensorSubnetSelectViewFactory {
    static func createPicker(
        for state: SubtensorSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        browseState: SubtensorSubnetBrowseState
    ) -> UIViewController? {
        guard let view = createView(for: state, delegate: delegate, browseState: browseState) else {
            return nil
        }

        return NovaNavigationController(rootViewController: view.controller)
    }

    static func createView(
        for state: SubtensorSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        browseState: SubtensorSubnetBrowseState
    ) -> SubtensorSubnetSelectViewProtocol? {
        let interactor = SubtensorSubnetSelectInteractor(
            state: state,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let localizationManager = LocalizationManager.shared

        let presenter = SubtensorSubnetSelectPresenter(
            interactor: interactor,
            wireframe: SubtensorSubnetSelectWireframe(state: state),
            viewModelFactory: SubtensorSubnetViewModelFactory(chainAsset: state.stakingOption.chainAsset),
            delegate: delegate,
            localizationManager: localizationManager,
            browseState: browseState
        )

        let view = SubtensorSubnetSelectViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
