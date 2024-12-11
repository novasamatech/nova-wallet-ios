import Foundation

struct SwapRouteDetailsViewFactory {
    static func createView(
        for _: AssetExchangeQuote,
        fee _: AssetExchangeFee,
        state _: SwapTokensFlowStateProtocol
    ) -> SwapRouteDetailsViewProtocol? {
        let interactor = SwapRouteDetailsInteractor()
        let wireframe = SwapRouteDetailsWireframe()

        let presenter = SwapRouteDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = SwapRouteDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
