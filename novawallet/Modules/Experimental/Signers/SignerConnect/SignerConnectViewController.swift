import UIKit
import SoraFoundation

final class SignerConnectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SignerConnectViewLayout

    let presenter: SignerConnectPresenterProtocol

    private var iconViewModel: ImageViewModelProtocol?

    init(presenter: SignerConnectPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SignerConnectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        presenter.setup()
    }

    private func configure() {
        rootView.accountView.addTarget(self, action: #selector(actionDidSelectAccount), for: .touchUpInside)
        rootView.statusView.addTarget(self, action: #selector(actionDidSelectStatus), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.signerBeaconTitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.locale = selectedLocale
    }

    @objc private func actionDidSelectAccount() {
        presenter.presentAccountOptions()
    }

    @objc private func actionDidSelectStatus() {
        presenter.presentConnectionDetails()
    }
}

extension SignerConnectViewController: SignerConnectViewProtocol {
    func didReceive(viewModel: SignerConnectViewModel) {
        iconViewModel?.cancel(on: rootView.appView.imageView)
        rootView.appView.imageView.image = nil

        let size = CGSize(width: 64, height: 64)

        iconViewModel = viewModel.icon
        viewModel.icon?.loadImage(on: rootView.appView.imageView, targetSize: size, animated: true)

        rootView.appView.detailsLabel.text = viewModel.title

        rootView.connectionInfoView.bind(details: viewModel.connection)

        let viewModel = StackCellViewModel(
            details: viewModel.accountName,
            imageViewModel: DrawableIconViewModel(icon: viewModel.accountIcon)
        )

        rootView.accountView.bind(viewModel: viewModel)

        rootView.setNeedsLayout()
    }

    func didReceive(status: SignerConnectStatus) {
        let details: String

        switch status {
        case .active:
            details = R.string.localizable.signerConnectStatusActive(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .connecting:
            details = R.string.localizable.signerConnectStatusConnecting(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .inactive:
            details = R.string.localizable.signerConnectStatusInactive(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .failed:
            details = R.string.localizable.signerConnectStatusFailed(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        rootView.statusView.bind(details: details)
    }
}

extension SignerConnectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
