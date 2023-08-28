import UIKit
import SoraFoundation

final class NPoolsUnstakeSetupViewController: UIViewController {
    typealias RootViewType = NPoolsUnstakeSetupViewLayout

    let presenter: NPoolsUnstakeSetupPresenterProtocol

    init(presenter: NPoolsUnstakeSetupPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NPoolsUnstakeSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingUnbond_v190(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension NPoolsUnstakeSetupViewController: NPoolsUnstakeSetupViewProtocol {
    func didReceiveAssetBalance(viewModel _: AssetBalanceViewModelProtocol) {}

    func didReceiveInput(viewModel _: AmountInputViewModelProtocol) {}

    func didReceiveFee(viewModel _: BalanceViewModelProtocol?) {}

    func didReceiveTransferable(viewModel _: BalanceViewModelProtocol?) {}

    func didReceiveHints(viewModel _: [String]) {}
}

extension NPoolsUnstakeSetupViewController: ImportantViewProtocol {}

extension NPoolsUnstakeSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
