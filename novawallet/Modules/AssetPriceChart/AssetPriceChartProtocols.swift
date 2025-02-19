protocol AssetPriceChartViewProtocol: AnyObject {
    func update(with widgetViewModel: AssetPriceChartWidgetViewModel)
}

protocol AssetPriceChartPresenterProtocol: AnyObject {
    func setup()
}

protocol AssetPriceChartInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetPriceChartInteractorOutputProtocol: AnyObject {}

protocol AssetPriceChartWireframeProtocol: AnyObject {}
