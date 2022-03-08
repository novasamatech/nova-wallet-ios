import Foundation

final class NftListWireframe: NftListWireframeProtocol {
    func showNftDetails(from view: NftListViewProtocol?, model: NftChainModel) {
        guard let nftDetails = NftDetailsViewFactory.createView(from: model) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nftDetails.controller,
            animated: true
        )
    }
}
