import UIKit

final class StakingDashboardViewController: UIViewController {
    typealias RootViewType = StakingDashboardViewLayout

    let presenter: StakingDashboardPresenterProtocol

    init(presenter: StakingDashboardPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingDashboardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingDashboardViewController: StakingDashboardViewProtocol {}