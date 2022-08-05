import Foundation
import UIKit
import SoraFoundation
import SoraUI

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

            rootView.proceedButton.imageWithTitleView?.title = R.string.localizable
                .commonContinue(preferredLanguages: selectedLocale.rLanguages)
        } else {
            rootView.proceedButton.applyDisabledStyle()
            rootView.proceedButton.isUserInteractionEnabled = false

            rootView.proceedButton.imageWithTitleView?.title = R.string.localizable
                .walletCreateButtonTitleDisabled_v2_2_0(preferredLanguages: selectedLocale.rLanguages)
        }

        rootView.proceedButton.invalidateLayout()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.walletNicknameCreateTitle_v2_2_0(preferredLanguages: languages)

        rootView.subtitleLabel.text = R.string.localizable.walletNicknameCreateSubtitle_v2_2_0(
            preferredLanguages: languages
        )

        rootView.captionLabel.text = R.string.localizable.walletNicknameCreateCaption_v2_2_0(
            preferredLanguages: languages
        )

        let walletNickname = R.string.localizable.walletUsernameSetupChooseTitle_v2_2_0(
            preferredLanguages: languages
        )

        rootView.walletNameTitleLabel.text = walletNickname

        let placeholder = NSAttributedString(
            string: walletNickname,
            attributes: [
                .foregroundColor: R.color.colorWhite32()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.walletNameInputView.textField.attributedPlaceholder = placeholder

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
