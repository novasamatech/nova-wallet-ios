import UIKit

final class DelegationListViewController: UIViewController {
    typealias RootViewType = DelegationListViewLayout

    let presenter: DelegationListPresenterProtocol

    init(presenter: DelegationListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DelegationListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DelegationListViewController: DelegationListViewProtocol {}
