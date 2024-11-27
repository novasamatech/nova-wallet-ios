import UIKit

final class DAppBrowserWidgetViewController: UIViewController {
    typealias RootViewType = DAppBrowserWidgetViewLayout

    let presenter: DAppBrowserWidgetPresenterProtocol

    init(presenter: DAppBrowserWidgetPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppBrowserWidgetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DAppBrowserWidgetViewController: DAppBrowserWidgetViewProtocol {}