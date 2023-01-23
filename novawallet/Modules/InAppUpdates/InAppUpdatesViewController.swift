import UIKit

final class InAppUpdatesViewController: UIViewController {
    typealias RootViewType = InAppUpdatesViewLayout

    let presenter: InAppUpdatesPresenterProtocol

    init(presenter: InAppUpdatesPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = InAppUpdatesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension InAppUpdatesViewController: InAppUpdatesViewProtocol {}
