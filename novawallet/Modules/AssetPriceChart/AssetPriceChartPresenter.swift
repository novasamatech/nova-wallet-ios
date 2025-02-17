import Foundation

final class AssetPriceChartPresenter {
    weak var view: AssetPriceChartViewProtocol?
    let wireframe: AssetPriceChartWireframeProtocol
    let interactor: AssetPriceChartInteractorInputProtocol

    init(
        interactor: AssetPriceChartInteractorInputProtocol,
        wireframe: AssetPriceChartWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AssetPriceChartPresenter: AssetPriceChartPresenterProtocol {
    func setup() {}
}

extension AssetPriceChartPresenter: AssetPriceChartInteractorOutputProtocol {}