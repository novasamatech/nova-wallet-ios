import UIKit

final class StakingSetupAmountViewController: UIViewController {
    typealias RootViewType = StakingSetupAmountViewLayout

    let presenter: StakingSetupAmountPresenterProtocol

    init(presenter: StakingSetupAmountPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingSetupAmountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingSetupAmountViewController: StakingSetupAmountViewProtocol {}
