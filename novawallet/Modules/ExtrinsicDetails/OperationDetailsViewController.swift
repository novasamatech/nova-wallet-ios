import UIKit

final class OperationDetailsViewController: UIViewController {
    typealias RootViewType = OperationDetailsViewLayout

    let presenter: OperationDetailsPresenterProtocol

    init(presenter: OperationDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = OperationDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension OperationDetailsViewController: OperationDetailsViewProtocol {
    func didReceive(viewModel _: OperationDetailsViewModel) {}
}
