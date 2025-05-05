import UIKit
import Foundation_iOS

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

        rootView.qrTypeSwitch.addTarget(
            self,
            action: #selector(actionToggleQrFormat),
            for: .valueChanged
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

        rootView.qrTypeSwitch.titles = [
            R.string.localizable.polkadotVaultQrTypeV7(
                preferredLanguages: languages
            ),
            R.string.localizable.polkadotVaultQrTypeLegacy(
                preferredLanguages: languages
            )
        ]

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

    @objc private func actionToggleQrFormat() {
        presenter.toggleExtrinsicFormat()
    }

    @objc private func actionClose() {
        presenter.close()
    }
}

extension ParitySignerTxQrViewController: ParitySignerTxQrViewProtocol {
    func didReceiveWallet(viewModel: WalletAccountViewModel) {
        rootView.accountDetailsView.bind(viewModel: viewModel)
    }

    func didReceiveCode(viewModel: QRImageViewModel?) {
        rootView.qrView.imageView.bindQr(viewModel: viewModel)
    }

    func didReceiveQrFormat(viewModel: ParitySignerTxFormatViewModel) {
        switch viewModel {
        case .none:
            rootView.qrTypeSwitch.isHidden = true
        case .new:
            rootView.qrTypeSwitch.isHidden = false

            rootView.qrTypeSwitch.selectedSegmentIndex = 0
        case .legacy:
            rootView.qrTypeSwitch.isHidden = false

            rootView.qrTypeSwitch.selectedSegmentIndex = 1
        }
    }

    func didReceiveExpiration(viewModel: ExpirationTimeViewModel?) {
        if let viewModel {
            rootView.timerLabel.isHidden = false
            rootView.timerLabel.bindQr(viewModel: viewModel, locale: selectedLocale)
        } else {
            rootView.timerLabel.isHidden = true
        }
    }
}

extension ParitySignerTxQrViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
