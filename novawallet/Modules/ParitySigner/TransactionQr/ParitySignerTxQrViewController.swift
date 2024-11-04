import UIKit
import SoraFoundation

final class ParitySignerTxQrViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = ParitySignerTxQrViewLayout

    let presenter: ParitySignerTxQrPresenterProtocol
    let type: ParitySignerType

    init(
        presenter: ParitySignerTxQrPresenterProtocol,
        type: ParitySignerType,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.type = type

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    private var accountDetailsViewModel: WalletAccountViewModel?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParitySignerTxQrViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupHandlers()
        setupLocalization()

        let qrSize = rootView.qrImageSize

        presenter.setup(qrSize: CGSize(width: qrSize, height: qrSize))
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = rootView.closeBarItem
    }

    private func setupHandlers() {
        rootView.accountDetailsView.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )

        rootView.helpButton.addTarget(
            self,
            action: #selector(actionSelectSecondaryAction),
            for: .touchUpInside
        )

        rootView.continueButton.addTarget(
            self,
            action: #selector(actionSelectMainAction),
            for: .touchUpInside
        )

        rootView.closeBarItem.target = self
        rootView.closeBarItem.action = #selector(actionClose)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.paritySignerTxTitle(
            type.getName(for: selectedLocale),
            preferredLanguages: languages
        )

        rootView.titleLabel.text = R.string.localizable.paritySignerTxScan(
            type.getName(for: selectedLocale),
            preferredLanguages: languages
        )

        rootView.helpButton.imageWithTitleView?.title = R.string.localizable.paritySignerTxSecondaryAction(
            type.getName(for: selectedLocale),
            preferredLanguages: languages
        )

        rootView.continueButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )
    }

    @objc private func actionSelectAccount() {
        presenter.activateAddressDetails()
    }

    @objc private func actionSelectSecondaryAction() {
        presenter.activateTroubleshouting()
    }

    @objc private func actionSelectMainAction() {
        presenter.proceed()
    }

    @objc private func actionClose() {
        presenter.close()
    }
}

extension ParitySignerTxQrViewController: ParitySignerTxQrViewProtocol {
    func didReceiveWallet(viewModel: WalletAccountViewModel) {
        rootView.accountDetailsView.bind(viewModel: viewModel)
    }

    func didReceiveCode(viewModel: QRImageViewModel) {
        rootView.qrView.imageView.bindQr(viewModel: viewModel)
    }

    func didReceiveExpiration(viewModel: ExpirationTimeViewModel) {
        rootView.timerLabel.bindQr(viewModel: viewModel, locale: selectedLocale)
    }
}

extension ParitySignerTxQrViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
