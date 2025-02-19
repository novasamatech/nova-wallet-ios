import Foundation

struct AssetPriceChartViewFactory {
    static func createView(
        asset: AssetModel,
        output: AssetPriceChartModuleOutputProtocol,
        inputOwner: AssetPriceChartInputOwnerProtocol,
        locale: Locale
    ) -> AssetPriceChartModule? {
        let interactor = AssetPriceChartInteractor()
        let wireframe = AssetPriceChartWireframe()

        let viewModelFactory = AssetPriceChartViewModelFactory()

        let presenter = AssetPriceChartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetModel: asset,
            viewModelFactory: viewModelFactory,
            locale: locale
        )

        let view = AssetPriceChartViewController(presenter: presenter)

        presenter.view = view
        presenter.moduleOutput = output
        interactor.presenter = presenter

        inputOwner.assetPriceChartModule = presenter

        return view
    }
}
