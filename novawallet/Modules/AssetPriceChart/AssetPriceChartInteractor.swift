import UIKit

final class AssetPriceChartInteractor {
    weak var presenter: AssetPriceChartInteractorOutputProtocol?
}

extension AssetPriceChartInteractor: AssetPriceChartInteractorInputProtocol {}
