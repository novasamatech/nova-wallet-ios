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
        configureState()
        setupLocalization()

        presenter.setup()
    }

    override func loadView() {
        view = AccountCreateViewLayout()
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

    private func configureState() {
        rootView.proceedButton.isEnabled = false
        rootView.proceedButton.applyDisabledStyle()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable
            .accountBackupMnemonicTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.subtitleLabel.text = R.string.localizable
            .accountCreateDetails_v2_2_0(preferredLanguages: selectedLocale.rLanguages)

        rootView.mnemonicFieldTitleLabel.text = R.string.localizable
            .accountBackupMnemonicFieldTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.captionLabel.text = R.string.localizable
            .accountBackupMnemonicCaption(preferredLanguages: selectedLocale.rLanguages)

        rootView.proceedButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: selectedLocale.rLanguages)

        rootView.proceedButton.invalidateLayout()
    }

    // MARK: - Actions

    @objc private func openAdvanced() {
        presenter.activateAdvanced()
    }

    @objc private func actionNext() {
        presenter.proceed()
    }
}

// MARK: - AccountCreateViewProtocol

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        rootView.mnemonicFieldContentLabel.textColor = .clear
        rootView.mnemonicFieldContentLabel.text = mnemonic.joined(separator: " ")

        presenter.prepareToDisplayMnemonic()
    }

    func displayMnemonic() {
        UIView.transition(with: rootView.mnemonicFieldContentLabel, duration: 0.25, options: .transitionCrossDissolve) {
            self.rootView.mnemonicFieldContentLabel.textColor = R.color.colorWhite()!
        }

        rootView.proceedButton.isEnabled = true
        rootView.proceedButton.applyEnabledStyle()
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
