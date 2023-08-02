import UIKit

final class StakingTypeViewController: UIViewController {
    typealias RootViewType = StakingTypeViewLayout

    let presenter: StakingTypePresenterProtocol

    init(presenter: StakingTypePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingTypeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingTypeViewController: StakingTypeViewProtocol {}
