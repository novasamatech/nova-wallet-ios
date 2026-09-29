import Foundation
import UIKit

final class BannersWireframe: BannersWireframeProtocol, SubtensorEarnInfoPresentable, SubtensorGetTaoRouting {
    let assetListModelObservable: AssetListModelObservable?

    init(assetListModelObservable: AssetListModelObservable?) {
        self.assetListModelObservable = assetListModelObservable
    }

    func showBittensorEarn(from view: BannersViewProtocol?, chainAsset: ChainAsset) {
        presentSubtensorEarnInfo(from: view, chainAsset: chainAsset)
    }

    func showBittensorGetTao(from view: BannersViewProtocol?, chainAsset: ChainAsset) {
        showGetTao(
            from: view,
            chainAsset: chainAsset,
            assetListObservable: assetListModelObservable,
            rampHandler: nil
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
