import UIKit
import SoraFoundation

final class NPoolsClaimRewardsViewController: UIViewController {
    typealias RootViewType = NPoolsClaimRewardsViewLayout

    let presenter: NPoolsClaimRewardsPresenterProtocol

    init(presenter: NPoolsClaimRewardsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
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

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {}
}

extension NPoolsClaimRewardsViewController: NPoolsClaimRewardsViewProtocol {
    func didReceiveAmount(viewModel _: BalanceViewModelProtocol) {}

    func didReceiveWallet(viewModel _: DisplayWalletViewModel) {}

    func didReceiveAccount(viewModel _: DisplayAddressViewModel) {}

    func didReceiveFee(viewModel _: BalanceViewModelProtocol?) {}

    func didReceiveClaimStrategy(viewModel _: NominationPools.ClaimRewardsStrategy) {}
}

extension NPoolsClaimRewardsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
