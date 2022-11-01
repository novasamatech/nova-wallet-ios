import UIKit

final class GovernanceUnlockSetupViewController: UIViewController {
    typealias RootViewType = GovernanceUnlockSetupViewLayout

    let presenter: GovernanceUnlockSetupPresenterProtocol

    init(presenter: GovernanceUnlockSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceUnlockSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GovernanceUnlockSetupViewController: GovernanceUnlockSetupViewProtocol {}