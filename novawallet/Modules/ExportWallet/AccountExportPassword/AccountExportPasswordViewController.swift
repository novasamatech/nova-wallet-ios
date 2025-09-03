import UIKit
import UIKit_iOS
import Foundation_iOS

final class AccountExportPasswordViewController: UIViewController, ImportantViewProtocol, ViewHolder {
    typealias RootViewType = AccountExportPasswordViewLayout

    let presenter: AccountExportPasswordPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    init(
        presenter: AccountExportPasswordPresenterProtocol,
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

    override func loadView() {
        view = AccountExportPasswordViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTextFields()
        setupButtonHandlers()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.exportPasswordTitle()

        rootView.subtitleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.accountExportJsonHint()

        let enterPasswordPlaceholder = NSAttributedString(
            string: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSetPassword(),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.enterPasswordView.textField.attributedPlaceholder = enterPasswordPlaceholder

        let confirmPasswordPlaceholder = NSAttributedString(
            string: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonConfirmPassword(),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.confirmPasswordView.textField.attributedPlaceholder = confirmPasswordPlaceholder

        updateNextButton()
    }

    private func setupTextFields() {
        rootView.enterPasswordView.delegate = self
        rootView.enterPasswordView.addTarget(
            self,
            action: #selector(actionPasswordInputChange),
            for: .editingChanged
        )

        rootView.confirmPasswordView.delegate = self
        rootView.confirmPasswordView.addTarget(
            self,
            action: #selector(actionConfirmationInputChange),
            for: .editingChanged
        )
    }

    private func setupButtonHandlers() {
        rootView.proceedButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
    }

    private func updateNextButton() {
        let enabled: Bool
        let title: String

        if let viewModel = rootView.enterPasswordView.inputViewModel, !viewModel.inputHandler.completed {
            enabled = false
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.exportPasswordProceedSetTitle()
        } else if
            let viewModel = rootView.confirmPasswordView.inputViewModel,
            !viewModel.inputHandler.completed {
            enabled = false
            title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.exportPasswordProceedConfirmTitle()
        } else {
            enabled = true
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.restoreJsonDownloadButton()
        }

        rootView.proceedButton.imageWithTitleView?.title = title

        if enabled {
            rootView.proceedButton.applyEnabledStyle()
        } else {
            rootView.proceedButton.applyDisabledStyle()
        }

        rootView.proceedButton.isUserInteractionEnabled = enabled
    }

    @objc private func actionPasswordInputChange() {
        updateNextButton()
    }

    @objc private func actionConfirmationInputChange() {
        updateNextButton()
    }

    @objc private func actionNext() {
        presenter.proceed()
    }
}

extension AccountExportPasswordViewController: AccountExportPasswordViewProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        rootView.enterPasswordView.bind(inputViewModel: viewModel)
        updateNextButton()
    }

    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) {
        rootView.confirmPasswordView.bind(inputViewModel: viewModel)
        updateNextButton()
    }
}

extension AccountExportPasswordViewController: PasswordInputViewDelegate {
    func passwordInputViewWillStartEditing(_: PasswordInputView) {}

    func passwordInputViewShouldReturn(_ inputView: PasswordInputView) -> Bool {
        if inputView === rootView.enterPasswordView {
            rootView.enterPasswordView.textField.resignFirstResponder()
            rootView.confirmPasswordView.textField.becomeFirstResponder()
        } else {
            rootView.confirmPasswordView.textField.resignFirstResponder()
        }

        return false
    }
}

extension AccountExportPasswordViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if rootView.enterPasswordView.isFirstResponder {
                targetView = rootView.enterPasswordView
            } else if rootView.confirmPasswordView.isFirstResponder {
                targetView = rootView.confirmPasswordView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension AccountExportPasswordViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
