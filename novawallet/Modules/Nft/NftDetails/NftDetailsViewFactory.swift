import Foundation

struct NftDetailsViewFactory {
    static func createView(from model: NftChainModel) -> NftDetailsViewProtocol? {
        let interactor = NftDetailsInteractor(nftChainModel: model)
        let wireframe = NftDetailsWireframe()

        let presenter = NftDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = NftDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
