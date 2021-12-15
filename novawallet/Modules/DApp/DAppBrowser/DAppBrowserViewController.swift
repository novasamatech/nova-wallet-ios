import UIKit

final class DAppBrowserViewController: UIViewController {
    typealias RootViewType = DAppBrowserViewLayout

    let presenter: DAppBrowserPresenterProtocol

    init(presenter: DAppBrowserPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppBrowserViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DAppBrowserViewController: DAppBrowserViewProtocol {}
