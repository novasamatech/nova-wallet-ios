import UIKit
import SoraFoundation

final class CreateWatchOnlyViewController: UIViewController, ViewHolder {
    typealias RootViewType = CreateWatchOnlyViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: CreateWatchOnlyPresenterProtocol

    init(presenter: CreateWatchOnlyPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CreateWatchOnlyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

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
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.welcomeWatchOnlyTitle(preferredLanguages: languages)
        rootView.detailsLabel.text = R.string.localizable.createWatchOnlyDetails(preferredLanguages: languages)
        rootView.presetsTitleLabel.text = R.string.localizable.commonWalletPresets(preferredLanguages: languages)

        let walletNickname = R.string.localizable.walletUsernameSetupChooseTitle(preferredLanguages: languages)
        rootView.walletNameTitleLabel.text = walletNickname

        let placeholder = NSAttributedString(
            string: walletNickname,
            attributes: [
                .foregroundColor: R.color.colorWhite32()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.walletNameInputView.textField.attributedPlaceholder = placeholder
        rootView.walletNameHintLabel.text = R.string.localizable.walletNicknameCreateCaption(
            preferredLanguages: languages
        )

        rootView.substrateAddressTitleLabel.text = R.string.localizable.commonSubstrateAddressTitle(
            preferredLanguages: languages
        )

        rootView.substrateAddressInputView.locale = selectedLocale
        rootView.evmAddressInputView.locale = selectedLocale

        rootView.substrateAddressHintLabel.text = R.string.localizable.commonSubstrateAddressHint(
            preferredLanguages: languages
        )

        updateActionButtonState()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionContinue), for: .touchUpInside)

        rootView.walletNameInputView.addTarget(
            self,
            action: #selector(actionNicknameChanged),
            for: .editingChanged
        )

        rootView.substrateAddressInputView.addTarget(
            self,
            action: #selector(actionSubstrateAddressChanged),
            for: .editingChanged
        )

        rootView.substrateAddressInputView.scanButton.addTarget(
            self,
            action: #selector(actionSubstrateAddressScan),
            for: .touchUpInside
        )

        rootView.evmAddressInputView.addTarget(
            self,
            action: #selector(actionEVMAddressChanged),
            for: .editingChanged
        )

        rootView.evmAddressInputView.scanButton.addTarget(
            self,
            action: #selector(actionEVMAddressScan),
            for: .touchUpInside
        )
    }

    private func updateActionButtonState() {
        if !rootView.walletNameInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .createWatchOnlyMissingNickname(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

        if !rootView.substrateAddressInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .createWatchOnlyMissingSubstrate(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.actionButton.invalidateLayout()
    }

    @objc private func actionNicknameChanged() {
        let partialNickName = rootView.walletNameInputView.textField.text ?? ""
        presenter.updateWalletNickname(partialNickName)

        updateActionButtonState()
    }

    @objc private func actionSubstrateAddressChanged() {
        let partialAddress = rootView.substrateAddressInputView.textField.text ?? ""
        presenter.updateSubstrateAddress(partialAddress)

        updateActionButtonState()
    }

    @objc private func actionSubstrateAddressScan() {
        presenter.performSubstrateScan()
    }

    @objc private func actionEVMAddressChanged() {
        let partialAddress = rootView.evmAddressInputView.textField.text ?? ""
        presenter.updateEVMAddress(partialAddress)
    }

    @objc private func actionEVMAddressScan() {
        presenter.performEVMScan()
    }

    @objc private func actionContinue() {
        presenter.performContinue()
    }
}

extension CreateWatchOnlyViewController: KeyboardAdoptable {
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

            if rootView.walletNameInputView.textField.isFirstResponder {
                targetView = rootView.walletNameInputView
            } else if rootView.substrateAddressInputView.textField.isFirstResponder {
                targetView = rootView.substrateAddressInputView
            } else if rootView.evmAddressInputView.textField.isFirstResponder {
                targetView = rootView.evmAddressInputView
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

extension CreateWatchOnlyViewController: CreateWatchOnlyViewProtocol {}

extension CreateWatchOnlyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
