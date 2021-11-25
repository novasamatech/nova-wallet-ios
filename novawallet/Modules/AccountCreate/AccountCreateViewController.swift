import Foundation
import UIKit
import SoraFoundation

final class AccountCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountCreateViewLayout

    let presenter: AccountCreatePresenterProtocol

    // MARK: - Lifecycle

    init(
        presenter: AccountCreatePresenterProtocol,
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

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        configureActions()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // TODO: Display alert
        // presenter.displayMnemonicAlert()
    }

    // MARK: - Setup functions

    private func setupNavigationItem() {
//        let infoItem = UIBarButtonItem(
//            image: R.image.iconInfo(),
//            style: .plain,
//            target: self,
//            action: #selector(actionOpenInfo)
//        )
//        navigationItem.rightBarButtonItem = infoItem
        // TODO: Fill
    }

    private func configureActions() {
        // TODO: Fill
    }

    private func setupLocalization() {
        // TODO: Fill
    }

    // MARK: - Actions

    @objc private func displayMnemonic() {
        // TODO: I understand action — display menmonic
        // presenter.proceedToMnemonic()
    }

    @objc private func actionNext() {
//        presenter.proceed()
        // TODO: Fill
    }

    @objc private func actionCancel() {
        // TODO: Cancel action
        // presenter.cancel()
    }
}

// MARK: - AccountCreateViewProtocol

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic _: [String]) {
        /*
         setupMnemonicViewIfNeeded()

         mnemonicView?.bind(words: mnemonic, columnsCount: 2)
         */
        // TODO: Fill
    }
}

// MARK: - Localizable

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
