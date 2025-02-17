import UIKit

final class AssetPriceChartViewController: UIViewController {
    typealias RootViewType = AssetPriceChartViewLayout

    let presenter: AssetPriceChartPresenterProtocol

    init(presenter: AssetPriceChartPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetPriceChartViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AssetPriceChartViewController: AssetPriceChartViewProtocol {}