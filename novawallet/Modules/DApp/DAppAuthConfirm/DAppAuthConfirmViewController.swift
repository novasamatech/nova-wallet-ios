import UIKit
import SoraFoundation
import SoraUI

final class DAppAuthConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppAuthConfirmViewLayout

    let presenter: DAppAuthConfirmPresenterProtocol

    private var dAppName: String?

    init(presenter: DAppAuthConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: 432.0)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAuthConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.allowButton.addTarget(self, action: #selector(actionAllow), for: .touchUpInside)
        rootView.denyButton.addTarget(self, action: #selector(actionDeny), for: .touchUpInside)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        applyTitle()

        rootView.subtitleLabel.text = R.string.localizable.dappAuthSubtitle(preferredLanguages: languages)

        rootView.walletView.rowContentView.titleView.text = R.string.localizable.commonWallet(
            preferredLanguages: languages
        )

        rootView.dappView.titleLabel.text = R.string.localizable.commonDapp(
            preferredLanguages: languages
        )

        rootView.allowButton.imageWithTitleView?.title = R.string.localizable.commonAllow(
            preferredLanguages: languages
        )
        rootView.denyButton.imageWithTitleView?.title = R.string.localizable.commonReject(
            preferredLanguages: languages
        )
    }

    private func applyTitle() {
        let languages = selectedLocale.rLanguages

        let name = dAppName ?? R.string.localizable.commonDapp(preferredLanguages: languages)

        let title = R.string.localizable.dappAuthTitle(name, preferredLanguages: languages)

        rootView.titleLabel.text = title
    }

    @objc private func actionAllow() {
        presenter.allow()
    }

    @objc private func actionDeny() {
        presenter.deny()
    }
}

extension DAppAuthConfirmViewController: DAppAuthConfirmViewProtocol {
    func didReceive(viewModel: DAppAuthViewModel) {
        rootView.sourceAppIconView.bind(
            viewModel: viewModel.sourceImageViewModel,
            size: DAppAuthConfirmViewLayout.iconSize
        )

        rootView.destinationAppIconView.bind(
            viewModel: viewModel.destinationImageViewModel,
            size: DAppAuthConfirmViewLayout.iconSize
        )

        rootView.walletView.rowContentView.valueView.detailsLabel.text = viewModel.walletName

        let walletImageView = rootView.walletView.rowContentView.valueView.imageView
        walletImageView.image = viewModel.walletIcon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: DAppOperationConfirmViewLayout.listImageSize,
            contentScale: UIScreen.main.scale
        )

        rootView.dappView.valueLabel.text = viewModel.dApp

        dAppName = viewModel.origin
        applyTitle()

        view.setNeedsLayout()
    }
}

extension DAppAuthConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension DAppAuthConfirmViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }

    func presenterDidHide(_: ModalPresenterProtocol) {}
}
