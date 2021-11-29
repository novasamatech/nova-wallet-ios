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

    // MARK: - Setup functions

    private func setupNavigationItem() {
        let advancedBarButtonItem = UIBarButtonItem(
            image: R.image.iconOptions(),
            style: .plain,
            target: self,
            action: #selector(openAdvanced)
        )
        
        navigationItem.rightBarButtonItem = advancedBarButtonItem
    }

    private func configureActions() {
        rootView.proceedButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
    }

    private func setupLocalization() {
        // TODO: Fill
    }

    // MARK: - Actions

    @objc private func openAdvanced() {
        // TODO: Fill
    }
    
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
        /* TODO:
         1. Update mnemonic label to change its size
         2. Make mnemonic text invisible
         3. Display warning
         */
        
        /*
         setupMnemonicViewIfNeeded()

         mnemonicView?.bind(words: mnemonic, columnsCount: 2)
         */
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
