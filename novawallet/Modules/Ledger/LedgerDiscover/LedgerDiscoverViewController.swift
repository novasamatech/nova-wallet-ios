import UIKit

final class LedgerDiscoverViewController: UIViewController {
    typealias RootViewType = LedgerDiscoverViewLayout

    let presenter: LedgerDiscoverPresenterProtocol

    init(presenter: LedgerDiscoverPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LedgerDiscoverViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension LedgerDiscoverViewController: LedgerDiscoverViewProtocol {}
