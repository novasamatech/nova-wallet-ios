import UIKit
import SoraFoundation

final class GovRevokeDelegationConfirmViewController: UIViewController {
    typealias RootViewType = GovernanceRevokeDelegationConfirmViewLayout

    let presenter: GovernanceRevokeDelegationConfirmPresenterProtocol

    init(
        presenter: GovernanceRevokeDelegationConfirmPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceRevokeDelegationConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {}
}

extension GovRevokeDelegationConfirmViewController: GovernanceRevokeDelegationConfirmViewProtocol {
    func didReceiveWallet(viewModel _: StackCellViewModel) {}

    func didReceiveAccount(viewModel _: DisplayAddressViewModel) {}

    func didReceiveFee(viewModel _: BalanceViewModelProtocol?) {}

    func didReceiveDelegate(viewModel _: GovernanceDelegateStackCell.Model) {}

    func didReceiveTracks(viewModel _: GovernanceTracksViewModel) {}

    func didReceiveYourDelegation(viewModel _: GovernanceYourDelegationViewModel) {}

    func didReceiveUndelegatingPeriod(viewModel _: String) {}

    func didReceiveHints(viewModel _: [String]) {}
}

extension GovRevokeDelegationConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
