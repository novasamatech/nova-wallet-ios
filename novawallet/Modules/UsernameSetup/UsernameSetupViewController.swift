import Foundation
import UIKit
import SoraFoundation
import SoraUI

final class UserNameSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = UsernameSetupViewLayout

    let presenter: UsernameSetupPresenterProtocol

    private var viewModel: InputViewModelProtocol?
    private var isFirstLayoutCompleted: Bool = false

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
        configureTextField()
        setupLocalization()

        presenter.setup()
    }

    // MARK: - Setup functions

    private func configureActions() {
        rootView.nameField.addTarget(
            self, action: #selector(textFieldDidChange(_:)),
            for: .editingChanged
        )

        rootView.proceedButton.addTarget(
            self, action: #selector(actionNext),
            for: .touchUpInside
        )
    }

    private func configureTextField() {
        rootView.nameField.textField.returnKeyType = .done
        rootView.nameField.textField.textContentType = .nickname
        rootView.nameField.textField.autocapitalizationType = .sentences
        rootView.nameField.textField.autocorrectionType = .no
        rootView.nameField.textField.spellCheckingType = .no

        rootView.nameField.delegate = self
    }

    private func updateActionButton() {
        guard let viewModel = viewModel else {
            return
        }

        let isEnabled = viewModel.inputHandler.completed
        rootView.proceedButton.set(enabled: isEnabled)
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        rootView.titleLabel.text = R.string.localizable.walletNicknameCreateTitle(preferredLanguages: languages)

        rootView.subtitleLabel.text = R.string.localizable.walletNicknameCreateSubtitle(preferredLanguages: languages)

        rootView.captionLabel.text = R.string.localizable.walletNicknameCreateCaption(preferredLanguages: languages)

        rootView.nameField.title = R.string.localizable.walletUsernameSetupChooseTitle(preferredLanguages: languages)

        rootView.proceedButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: languages)
        rootView.proceedButton.invalidateLayout()
    }

    // MARK: - Actions

    @objc private func textFieldDidChange(_ sender: UITextField) {
        if viewModel?.inputHandler.value != sender.text {
            sender.text = viewModel?.inputHandler.value
        }

        updateActionButton()
    }

    @objc private func actionNext() {
        rootView.nameField.resignFirstResponder()
        presenter.proceed()
    }
}

// MARK: - AnimatedTextFieldDelegate

extension UserNameSetupViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = viewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - UsernameSetupViewProtocol

extension UserNameSetupViewController: UsernameSetupViewProtocol {
    func setInput(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel
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
