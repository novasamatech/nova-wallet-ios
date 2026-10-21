import Foundation
import Foundation_iOS
import UIKit
import NovaAnalytics

enum SubtensorSubnetSelectViewFactory {
    static func createPicker(
        for state: SubtensorSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        browseState: SubtensorSubnetBrowseState,
        source: SubnetListSource
    ) -> UIViewController? {
        guard let view = createView(for: state, delegate: delegate, browseState: browseState, source: source) else {
            return nil
        }

        return NovaNavigationController(rootViewController: view.controller)
    }

    static func createView(
        for state: SubtensorSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        browseState: SubtensorSubnetBrowseState,
        source: SubnetListSource
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
            chainAsset: state.stakingOption.chainAsset,
            delegate: delegate,
            localizationManager: localizationManager,
            browseState: browseState,
            source: source
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
