import UIKit

final class NPoolsRedeemViewController: UIViewController {
    typealias RootViewType = NPoolsRedeemViewLayout

    let presenter: NPoolsRedeemPresenterProtocol

    init(presenter: NPoolsRedeemPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NPoolsRedeemViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NPoolsRedeemViewController: NPoolsRedeemViewProtocol {
    func didReceiveAmount(viewModel _: BalanceViewModelProtocol) {}

    func didReceiveWallet(viewModel _: DisplayWalletViewModel) {}

    func didReceiveAccount(viewModel _: DisplayAddressViewModel) {}

    func didReceiveFee(viewModel _: BalanceViewModelProtocol?) {}
}
