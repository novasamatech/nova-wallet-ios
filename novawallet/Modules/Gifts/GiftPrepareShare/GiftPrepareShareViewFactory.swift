import Foundation

struct GiftPrepareShareViewFactory {
    static func createView(
        giftId _: GiftModel.Id,
        chainAsset: ChainAsset
    ) -> GiftPrepareShareViewProtocol? {
        let interactor = GiftPrepareShareInteractor()
        let wireframe = GiftPrepareShareWireframe()

        let presenter = GiftPrepareSharePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: GiftPrepareShareViewModelFactory(),
            chainAsset: chainAsset
        )

        let view = GiftPrepareShareViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
