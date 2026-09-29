import Foundation
import Foundation_iOS
import UIKit

enum SubtensorSubnetSelectViewFactory {
    static func createPicker(
        for state: SubtensorStakingSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate
    ) -> UIViewController? {
        guard let view = createView(for: state, delegate: delegate) else {
            return nil
        }

        return NovaNavigationController(rootViewController: view.controller)
    }

    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        delegateTake _: UInt16?
    ) -> SubtensorSubnetSelectViewProtocol? {
        createView(for: state, delegate: delegate)
    }

    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        delegate: SubtensorSubnetSelectDelegate
    ) -> SubtensorSubnetSelectViewProtocol? {
        let earnServices = state.earnServices

        let interactor = SubtensorSubnetSelectInteractor(
            catalogueService: earnServices.catalogueService,
            subnetsService: state.subnetsService,
            earnConfigProvider: earnServices.earnConfigProvider,
            yieldService: earnServices.yieldService,
            rankingViewService: earnServices.rankingViewService,
            priceHistoryService: earnServices.priceHistoryService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let localizationManager = LocalizationManager.shared

        let presenter = SubtensorSubnetSelectPresenter(
            interactor: interactor,
            wireframe: SubtensorSubnetSelectWireframe(state: state),
            viewModelFactory: SubtensorSubnetViewModelFactory(chainAsset: state.stakingOption.chainAsset),
            delegate: delegate,
            earnSettings: earnServices.earnSettings,
            localizationManager: localizationManager
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
