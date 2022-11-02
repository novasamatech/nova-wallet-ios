import UIKit

final class GovernanceUnlockConfirmViewController: UIViewController {
    typealias RootViewType = GovernanceUnlockConfirmViewLayout

    let presenter: GovernanceUnlockConfirmPresenterProtocol

    init(presenter: GovernanceUnlockConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceUnlockConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GovernanceUnlockConfirmViewController: GovernanceUnlockConfirmViewProtocol {}