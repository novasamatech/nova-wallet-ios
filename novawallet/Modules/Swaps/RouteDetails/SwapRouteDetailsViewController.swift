import UIKit

final class SwapRouteDetailsViewController: UIViewController {
    typealias RootViewType = SwapRouteDetailsViewLayout

    let presenter: SwapRouteDetailsPresenterProtocol

    init(presenter: SwapRouteDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapRouteDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwapRouteDetailsViewController: SwapRouteDetailsViewProtocol {}
