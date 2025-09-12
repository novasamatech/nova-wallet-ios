import Foundation
import UIKit
import Foundation_iOS
import UIKit_iOS

final class UserNameSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = UsernameSetupViewLayout

    let presenter: UsernameSetupPresenterProtocol

    // MARK: - Lifecycle

    init(
        presenter: UsernameSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UsernameSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureActions()
        setupLocalization()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rootView.walletNameInputView.textField.becomeFirstResponder()
    }

    // MARK: - Setup functions

    private func configureActions() {
        rootView.walletNameInputView.addTarget(
            self, action: #selector(textFieldDidChange),
            for: .editingChanged
        )

        rootView.proceedButton.addTarget(
            self, action: #selector(actionNext),
            for: .touchUpInside
        )
    }

    private func updateActionButton() {
        if rootView.walletNameInputView.completed {
            rootView.proceedButton.applyEnabledStyle()
            rootView.proceedButton.isUserInteractionEnabled = true

            rootView.proceedButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable
                .commonContinue()
        } else {
            rootView.proceedButton.applyDisabledStyle()
            rootView.proceedButton.isUserInteractionEnabled = false

            rootView.proceedButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable
                .commonEnterWalletNameDisabled()
        }

        rootView.proceedButton.invalidateLayout()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.walletNameTitle()

        rootView.subtitleLabel.text = R.string(preferredLanguages: languages).localizable.walletNameSubtitle()

        rootView.nameView.locale = selectedLocale

        updateActionButton()
    }

    // MARK: - Actions

    @objc private func textFieldDidChange() {
        updateActionButton()
    }

    @objc private func actionNext() {
        rootView.walletNameInputView.textField.resignFirstResponder()
        presenter.proceed()
    }
}

// MARK: - UsernameSetupViewProtocol

extension UserNameSetupViewController: UsernameSetupViewProtocol {
    func setInput(viewModel: InputViewModelProtocol) {
        rootView.walletNameInputView.bind(inputViewModel: viewModel)

        updateActionButton()
    }

    func setBadge(viewModel: TitleIconViewModel) {
        rootView.nameView.setBadge(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension UserNameSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
