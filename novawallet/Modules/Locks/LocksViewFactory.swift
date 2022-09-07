import Foundation
import SoraUI

struct LocksViewFactory {
    static func createView(input: LocksViewInput) -> LocksViewProtocol? {
        let wireframe = LocksWireframe()
        let presenter = LocksPresenter(
            input: input,
            wireframe: wireframe
        )
        let view = LocksViewController(presenter: presenter)

        presenter.view = view
        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let preferredContentSize = min(presenter.contentHeight, maxHeight)

        view.preferredContentSize = .init(
            width: 0,
            height: preferredContentSize
        )

        return view
    }
}

struct LocksViewInput {
    let prices: [ChainAssetId: PriceData]
    let balances: [AssetBalance]
    let chains: [ChainModel.Id: ChainModel]
    let locks: [AssetLock]
}
