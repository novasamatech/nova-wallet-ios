import UIKit

final class NotificationsViewController: UIViewController {
    typealias RootViewType = NotificationsViewLayout

    let presenter: NotificationsPresenterProtocol

    init(presenter: NotificationsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NotificationsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NotificationsViewController: NotificationsViewProtocol {}