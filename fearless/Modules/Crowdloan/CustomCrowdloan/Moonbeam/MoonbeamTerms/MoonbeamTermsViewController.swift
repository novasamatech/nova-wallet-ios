import UIKit
import SoraFoundation

final class MoonbeamTermsViewController: UIViewController, ViewHolder {
    typealias RootViewType = MoonbeamTermsViewLayout

    let presenter: MoonbeamTermsPresenterProtocol

    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    init(
        presenter: MoonbeamTermsPresenterProtocol,
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
        view = MoonbeamTermsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.termsSwitchView.addTarget(self, action: #selector(handleSwitch), for: .valueChanged)
        applyLocalization()
        presenter.setup()
    }

    @objc
    private func handleSwitch() {
        rootView.updateActionButton()
    }

    private func updateFee() {
        guard let viewModel = feeViewModel?.value(for: selectedLocale) else {
            return
        }
        rootView.bind(feeViewModel: viewModel)
    }
}

extension MoonbeamTermsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.locale = selectedLocale
            title = R.string.localizable.crowdloanTermsValue(preferredLanguages: selectedLocale.rLanguages)
            updateFee()
        }
    }
}

extension MoonbeamTermsViewController: MoonbeamTermsViewProtocol {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>) {
        feeViewModel = viewModel
        updateFee()
    }
}
