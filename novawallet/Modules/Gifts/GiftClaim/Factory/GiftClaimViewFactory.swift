import Foundation
import BigInt

struct GiftClaimViewFactory {
    static func createView(
        info: ClaimableGiftInfo,
        totalAmount: BigUInt
    ) -> GiftClaimViewProtocol? {
        let interactor = GiftClaimInteractor()
        let wireframe = GiftClaimWireframe()

        let presenter = GiftClaimPresenter(interactor: interactor, wireframe: wireframe)

        let view = GiftClaimViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
