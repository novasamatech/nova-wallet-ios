import Foundation
import Foundation_iOS

final class StakingDashboardWireframe: StakingDashboardWireframeProtocol {
    let stateObserver: Observable<StakingDashboardModel>
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol

    init(
        stateObserver: Observable<StakingDashboardModel>,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) {
        self.stateObserver = stateObserver
        self.delegatedAccountSyncService = delegatedAccountSyncService
    }

    func showMoreOptions(from view: ControllerBackedProtocol?) {
        guard let stakingMoreOptionsView = StakingMoreOptionsViewFactory.createView(stateObserver: stateObserver) else {
            return
        }

        stakingMoreOptionsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            stakingMoreOptionsView.controller,
            animated: true
        )
    }

    func showStakingDetails(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    ) {
        if option.type == .subtensor {
            showSubtensorStakingDetails(from: view, chainAsset: option.chainAsset)
            return
        }

        guard let detailsView = StakingMainViewFactory.createView(
            for: option,
            delegatedAccountSyncService: delegatedAccountSyncService
        ) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    private func showSubtensorStakingDetails(
        from view: StakingDashboardViewProtocol?,
        chainAsset: ChainAsset
    ) {
        // The active dashboard row for Bittensor can be backed by a subnet
        // alpha asset (e.g. SN8) when the user has stake in that subnet but
        // not in root. Inside the TAO Staking module everything must operate
        // on the TAO asset — staking always sources from TAO, and balance /
        // price / unit display would otherwise render in alpha. Normalize
        // here before any module wiring sees the chainAsset.
        //
        // If the chain config is missing the TAO asset (assetId 0) we bail
        // rather than silently fall back to the alpha asset — pushing the
        // staking screen with an alpha chainAsset would render amounts in
        // alpha units and look up the wrong price.
        guard let normalizedChainAsset = chainAsset.subtensorTaoAsset() else {
            Logger.shared.error(
                "TAO Staking: chain \(chainAsset.chain.chainId) is missing the native TAO asset; aborting entry"
            )
            return
        }

        // Capture which netuid the user tapped on. We normalize chainAsset
        // away from the SN# alpha asset for staking flows, but the dashboard
        // still wants to filter "Your positions" to only that subnet —
        // tapping the SN8 card should drill into SN8 positions, not all.
        // Native TAO asset has no typeExtras → root (netuid 0).
        let entryNetuid: UInt16 = SubtensorNetuidExtractor.extract(from: chainAsset.asset)
            ?? SubtensorStakingConstants.rootNetuid

        guard
            let wallet = SelectedWalletSettings.shared.value,
            let accountResponse = wallet.fetchMetaChainAccount(
                for: normalizedChainAsset.chain.accountRequest()
            )
        else { return }

        let coldkey = accountResponse.chainAccount.accountId
        let vc = SubtensorStakingViewFactory.createView(
            chainAsset: normalizedChainAsset,
            coldkey: coldkey,
            entryNetuid: entryNetuid
        )
        vc.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(vc, animated: true)
    }

    func showStartStaking(from view: StakingDashboardViewProtocol?, chainAsset: ChainAsset) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: chainAsset,
            selectedStakingType: nil
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: startStakingView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
