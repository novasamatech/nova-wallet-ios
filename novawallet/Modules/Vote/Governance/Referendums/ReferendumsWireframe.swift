import Foundation
import UIKit

final class ReferendumsWireframe: ReferendumsWireframeProtocol {
    let state: GovernanceSharedState
    let metaAccount: MetaAccountModel

    init(
        state: GovernanceSharedState,
        metaAccount: MetaAccountModel
    ) {
        self.state = state
        self.metaAccount = metaAccount
    }

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceAssetSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
    ) {
        guard let selectionView = GovernanceAssetSelectionViewFactory.createView(
            for: delegate,
            chainId: chainId,
            governanceType: governanceType
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showSwipeGov(from view: ControllerBackedProtocol?) {
        guard let swipeGovView = SwipeGovViewFactory.createView(
            metaAccount: metaAccount,
            sharedState: state
        ) else {
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

        view?.controller.present(navigationController, animated: true)
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

        view?.controller.present(navigationController, animated: true)
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
        searchView.controller.modalPresentationStyle = .fullScreen

        view?.controller.present(searchView.controller, animated: true, completion: nil)
    }
}
