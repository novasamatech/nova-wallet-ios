import UIKit

final class MythosStkClaimRewardsViewController: UIViewController {
    typealias RootViewType = MythosStkClaimRewardsViewLayout

    let presenter: MythosStkClaimRewardsPresenterProtocol

    init(presenter: MythosStkClaimRewardsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MythosStkClaimRewardsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension MythosStkClaimRewardsViewController: MythosStkClaimRewardsViewProtocol {}
