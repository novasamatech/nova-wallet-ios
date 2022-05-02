import UIKit
import SoraFoundation

final class ControllerAccountConfirmationVC: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = ControllerAccountConfirmationLayout

    let presenter: ControllerAccountConfirmationPresenterProtocol
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: ControllerAccountConfirmationPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
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
        view = ControllerAccountConfirmationLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupActions()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingControllerConfirmTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.controllerCell.titleLabel.text = R.string.localizable.stakingControllerAccountTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        applyFeeViewModel()
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    private func setupActions() {
        rootView.actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
        rootView.accountCell.addTarget(self, action: #selector(handleStashAction), for: .touchUpInside)
        rootView.controllerCell.addTarget(self, action: #selector(handleControllerAction), for: .touchUpInside)
    }

    @objc
    private func handleActionButton() {
        presenter.confirm()
    }

    @objc
    private func handleStashAction() {
        presenter.handleStashAction()
    }

    @objc
    private func handleControllerAction() {
        presenter.handleControllerAction()
    }
}

extension ControllerAccountConfirmationVC: ControllerAccountConfirmationViewProtocol {
    func reload(with viewModel: ControllerAccountConfirmationVM) {
        rootView.walletCell.bind(
            viewModel: viewModel.walletViewModel.cellViewModel
        )

        rootView.accountCell.bind(
            viewModel: viewModel.accountViewModel.cellViewModel
        )

        rootView.controllerCell.bind(
            viewModel: viewModel.controllerViewModel.cellViewModel
        )
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }
}

extension ControllerAccountConfirmationVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
