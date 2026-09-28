import Foundation
import UIKit

final class BannersWireframe: BannersWireframeProtocol {
    func showBittensorEarn(from view: BannersViewProtocol?) {
        guard
            let chainAsset = BittensorLocalBanner.chainAsset(),
            let stakingView = StartStakingInfoViewFactory.createSubtensorView(
                for: .init(chainAsset: chainAsset, type: .subtensor)
            )
        else { return }

        stakingView.controller.hidesBottomBarWhenPushed = true
        view?.controller.parent?.navigationController?.pushViewController(
            stakingView.controller,
            animated: true
        )
    }

    func openActionLink(urlString: String) {
        guard
            let url = URL(string: urlString),
            UIApplication.shared.canOpenURL(url)
        else { return }

        UIApplication.shared.open(url)
    }
}
