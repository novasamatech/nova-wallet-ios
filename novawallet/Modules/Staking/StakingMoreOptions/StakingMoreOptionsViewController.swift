import UIKit

final class StakingMoreOptionsViewController: UIViewController {
    typealias RootViewType = StakingMoreOptionsViewLayout

    let presenter: StakingMoreOptionsPresenterProtocol

    init(presenter: StakingMoreOptionsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingMoreOptionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingMoreOptionsViewController: StakingMoreOptionsViewProtocol {}
