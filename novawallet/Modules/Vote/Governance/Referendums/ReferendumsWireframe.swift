import Foundation
import UIKit

final class ReferendumsWireframe: ReferendumsWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceChainSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
    ) {
        guard let selectionView = GovernanceChainSelectionViewFactory.createView(
            for: delegate,
            chainId: chainId,
            governanceType: governanceType
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    func showSwipeGov(from view: ControllerBackedProtocol?) {
        guard let swipeGovView = SwipeGovViewFactory.createView(sharedState: state) else {
            return
        }

        swipeGovView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            swipeGovView.controller,
            animated: true
        )
    }

    func showReferendumDetails(from view: ControllerBackedProtocol?, initData: ReferendumDetailsInitData) {
        guard
            let detailsView = ReferendumDetailsViewFactory.createView(
                for: state,
                initData: initData
            ) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }

    func showUnlocksDetails(from view: ControllerBackedProtocol?, initData: GovernanceUnlockInitData) {
        guard let unlocksView = GovernanceUnlockSetupViewFactory.createView(for: state, initData: initData) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unlocksView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showAddDelegation(from view: ControllerBackedProtocol?) {
        guard let delegationsView = AddDelegationViewFactory.createView(state: state) else {
            return
        }

        delegationsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(delegationsView.controller, animated: true)
    }

    func showYourDelegations(from view: ControllerBackedProtocol?) {
        guard let delegationsView = GovernanceYourDelegationsViewFactory.createView(for: state) else {
            return
        }

        delegationsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(delegationsView.controller, animated: true)
    }

    func showFilters(
        from view: ControllerBackedProtocol?,
        delegate: ReferendumsFiltersDelegate,
        filter: ReferendumsFilter
    ) {
        guard let filtersView = ReferendumsFiltersViewFactory.createView(
            delegate: delegate,
            filter: filter
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: filtersView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showSearch(
        from view: ControllerBackedProtocol?,
        referendumsState: Observable<ReferendumsViewState>,
        delegate: ReferendumSearchDelegate?
    ) {
        guard let searchView = ReferendumSearchViewFactory.createView(
            state: referendumsState,
            governanceState: state,
            delegate: delegate
        ) else {
            return
        }

        searchView.controller.modalTransitionStyle = .crossDissolve
        searchView.controller.modalPresentationStyle = .overCurrentContext

        view?.controller.present(searchView.controller, animated: true, completion: nil)
    }

    func showWalletDetails(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    ) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }
}
