import UIKit

final class NPoolsClaimRewardsViewController: UIViewController {
    typealias RootViewType = NPoolsClaimRewardsViewLayout

    let presenter: NPoolsClaimRewardsPresenterProtocol

    init(presenter: NPoolsClaimRewardsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NPoolsClaimRewardsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NPoolsClaimRewardsViewController: NPoolsClaimRewardsViewProtocol {}
