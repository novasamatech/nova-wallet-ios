import UIKit

final class GovernanceYourDelegationsViewController: UIViewController {
    typealias RootViewType = GovernanceYourDelegationsViewLayout

    let presenter: GovernanceYourDelegationsPresenterProtocol

    init(presenter: GovernanceYourDelegationsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceYourDelegationsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GovernanceYourDelegationsViewController: GovernanceYourDelegationsViewProtocol {
    func didReceive(viewModels _: [GovernanceYourDelegationCell.Model]) {}
}
