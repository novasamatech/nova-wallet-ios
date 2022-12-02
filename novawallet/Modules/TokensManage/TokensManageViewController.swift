import UIKit
import SoraFoundation

final class TokensManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageViewLayout

    let presenter: TokensManagePresenterProtocol

    init(presenter: TokensManagePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensManageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        setupLocalization()

        presenter.setup()
    }

    private func setupTopBar() {
        navigationItem.rightBarButtonItem = rootView.addTokenButton

        rootView.addTokenButton.target = self
        rootView.addTokenButton.action = #selector(actionAddToken)
    }

    private func setupLocalization() {
        title = R.string.localizable.assetsManageTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.addTokenButton.title = R.string.localizable.commonAddToken(
            preferredLanguages: selectedLocale.rLanguages
        )

        let placeholder = R.string.localizable.tokensManageSearch(preferredLanguages: selectedLocale.rLanguages)
        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText()!
            ]
        )
    }

    @objc private func actionAddToken() {}
}

extension TokensManageViewController: TokensManageViewProtocol {}

extension TokensManageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
