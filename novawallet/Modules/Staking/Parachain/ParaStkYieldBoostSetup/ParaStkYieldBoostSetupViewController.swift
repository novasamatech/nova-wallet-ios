import UIKit
import CommonWallet

final class ParaStkYieldBoostSetupViewController: UIViewController {
    typealias RootViewType = ParaStkYieldBoostSetupViewLayout

    let presenter: ParaStkYieldBoostSetupPresenterProtocol

    init(presenter: ParaStkYieldBoostSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkYieldBoostSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ParaStkYieldBoostSetupViewController: ParaStkYieldBoostSetupViewProtocol {
    func didReceiveCollator(viewModel _: AccountDetailsSelectionViewModel?) {}

    func didReceiveRewardComparison(viewModel _: ParaStkYieldBoostComparisonViewModel) {}

    func didReceiveYieldBoostSelected(_: Bool) {}

    func didReceiveYieldBoostPeriod(days _: UInt?) {}

    func didReceiveAssetBalance(viewModel _: AssetBalanceViewModelProtocol) {}

    func didReceiveAmount(inputViewModel _: AmountInputViewModelProtocol) {}
}
