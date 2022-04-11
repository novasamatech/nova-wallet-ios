import UIKit
import SoraFoundation
import SoraUI

final class DAppPhishingViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppPhishingViewLayout

    let presenter: DAppPhishingPresenterProtocol

    init(
        presenter: DAppPhishingPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: 300.0)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppPhishingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionGoBack),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.dappPhishingTitle(preferredLanguages: languages)
        rootView.subtitleLabel.text = R.string.localizable.dappPhishingMessage(
            preferredLanguages: languages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.dappPhishingAction(
            preferredLanguages: languages
        )
    }

    @objc func actionGoBack() {
        presenter.goBack()
    }
}

extension DAppPhishingViewController: DAppPhishingViewProtocol {}

extension DAppPhishingViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension DAppPhishingViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }

    func presenterDidHide(_: ModalPresenterProtocol) {}
}
