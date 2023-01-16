import UIKit

final class AddDelegationViewController: UIViewController {
    typealias RootViewType = AddDelegationViewLayout

    let presenter: AddDelegationPresenterProtocol

    init(presenter: AddDelegationPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AddDelegationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AddDelegationViewController: AddDelegationViewProtocol {}
