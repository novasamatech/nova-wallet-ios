import UIKit

final class GovernanceDelegateInfoViewController: UIViewController {
    typealias RootViewType = GovernanceDelegateInfoViewLayout

    let presenter: GovernanceDelegateInfoPresenterProtocol

    init(presenter: GovernanceDelegateInfoPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceDelegateInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GovernanceDelegateInfoViewController: GovernanceDelegateInfoViewProtocol {}
