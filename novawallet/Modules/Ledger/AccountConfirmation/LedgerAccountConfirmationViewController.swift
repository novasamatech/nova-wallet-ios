import UIKit

final class LedgerAccountConfirmationViewController: UIViewController {
    typealias RootViewType = LedgerAccountConfirmationViewLayout

    let presenter: LedgerAccountConfirmationPresenterProtocol

    init(presenter: LedgerAccountConfirmationPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LedgerAccountConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension LedgerAccountConfirmationViewController: LedgerAccountConfirmationViewProtocol {
    func didAddAccount(viewModel _: LedgerAccountViewModel) {}

    func didStartLoading() {}

    func didStopLoading() {}
}
