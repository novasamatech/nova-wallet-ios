import Foundation

struct AssetPriceChartViewFactory {
    static func createView() -> AssetPriceChartViewProtocol? {
        let interactor = AssetPriceChartInteractor()
        let wireframe = AssetPriceChartWireframe()

        let presenter = AssetPriceChartPresenter(interactor: interactor, wireframe: wireframe)

        let view = AssetPriceChartViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
