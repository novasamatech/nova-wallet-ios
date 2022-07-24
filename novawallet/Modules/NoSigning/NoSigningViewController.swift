import UIKit
import SoraFoundation

final class NoSigningViewController: UIViewController, ViewHolder {
    typealias RootViewType = NoSigningViewLayout

    let presenter: NoSigningPresenterProtocol

    init(presenter: NoSigningPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
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
        view = NoSigningViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.noKeyTitle(preferredLanguages: languages)
        rootView.detailsLabel.text = R.string.localizable.noKeyMessage(preferredLanguages: languages)

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonOkBack(
            preferredLanguages: languages
        )
        rootView.actionButton.invalidateLayout()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionGoBack), for: .touchUpInside)
    }

    @objc private func actionGoBack() {
        presenter.goBack()
    }
}

extension NoSigningViewController: NoSigningViewProtocol {}

extension NoSigningViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
