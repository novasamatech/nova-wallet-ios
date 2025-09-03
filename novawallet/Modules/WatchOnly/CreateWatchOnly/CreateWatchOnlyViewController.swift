import UIKit
import Foundation_iOS
import UIKit_iOS

final class CreateWatchOnlyViewController: UIViewController, ViewHolder {
    typealias RootViewType = CreateWatchOnlyViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: CreateWatchOnlyPresenterProtocol

    var evmFieldEmpty: Bool { (rootView.evmAddressInputView.textField.text ?? "").isEmpty }

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

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.welcomeWatchOnlyTitle()
        rootView.detailsLabel.text = R.string(preferredLanguages: languages).localizable.createWatchOnlyDetails()
        rootView.presetsTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonWalletPresets()

        let walletNickname = R.string(preferredLanguages: languages).localizable.walletUsernameSetupChooseTitle()
        rootView.walletNameTitleLabel.text = walletNickname

        let placeholder = NSAttributedString(
            string: walletNickname,
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.walletNameInputView.textField.attributedPlaceholder = placeholder
        rootView.walletNameHintLabel.text = R.string(preferredLanguages: languages).localizable.walletNicknameCreateCaption_v2_2_0()

        rootView.substrateAddressTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonSubstrateAddressTitle()

        rootView.substrateAddressInputView.locale = selectedLocale

        rootView.substrateAddressHintLabel.text = R.string(preferredLanguages: languages).localizable.commonSubstrateAddressHint()

        rootView.evmAddressTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonEvmAddressOptionalTitle()

        rootView.evmAddressInputView.locale = selectedLocale

        rootView.evmAddressHintLabel.text = R.string(preferredLanguages: languages).localizable.commonEvmAddressHint()

        updateActionButtonState()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionContinue), for: .touchUpInside)

        rootView.walletNameInputView.delegate = self

        rootView.walletNameInputView.addTarget(
            self,
            action: #selector(actionNicknameChanged),
            for: .editingChanged
        )

        rootView.substrateAddressInputView.delegate = self

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

        rootView.evmAddressInputView.delegate = self

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

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                .createWatchOnlyMissingNickname()
            rootView.actionButton.invalidateLayout()

            return
        }

        if !rootView.substrateAddressInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                .createWatchOnlyMissingSubstrate()
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonContinue()
        rootView.actionButton.invalidateLayout()
    }

    private func updateReturnButton(for selectedInputView: UIView) {
        if selectedInputView === rootView.walletNameInputView {
            if rootView.substrateAddressInputView.completed, !evmFieldEmpty {
                rootView.walletNameInputView.textField.returnKeyType = .done
            } else {
                rootView.walletNameInputView.textField.returnKeyType = .next
            }
        }

        if selectedInputView === rootView.substrateAddressInputView {
            if !evmFieldEmpty {
                rootView.substrateAddressInputView.textField.returnKeyType = .done
            } else {
                rootView.substrateAddressInputView.textField.returnKeyType = .next
            }
        }
    }

    private func completeInputOn(field: UIView) {
        if field === rootView.walletNameInputView {
            rootView.walletNameInputView.textField.resignFirstResponder()

            if !rootView.substrateAddressInputView.completed {
                rootView.substrateAddressInputView.textField.becomeFirstResponder()
            } else if evmFieldEmpty {
                rootView.evmAddressInputView.textField.becomeFirstResponder()
            }
        }

        if field === rootView.substrateAddressInputView {
            rootView.substrateAddressInputView.textField.resignFirstResponder()

            if evmFieldEmpty {
                rootView.evmAddressInputView.textField.becomeFirstResponder()
            }
        }

        if field === rootView.evmAddressInputView {
            rootView.evmAddressInputView.textField.resignFirstResponder()
        }
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

    @objc private func actionPreset(_ sender: RoundedButton) {
        guard let index = rootView.presetsContainerView.stackView.arrangedSubviews.firstIndex(of: sender) else {
            return
        }

        presenter.selectPreset(at: index)
    }
}

extension CreateWatchOnlyViewController: TextInputViewDelegate {
    func textInputViewShouldReturn(_ inputView: TextInputView) -> Bool {
        completeInputOn(field: inputView)
        return true
    }

    func textInputViewWillStartEditing(_ inputView: TextInputView) {
        updateReturnButton(for: inputView)
    }
}

extension CreateWatchOnlyViewController: AccountInputViewDelegate {
    func accountInputViewDidEndEditing(_: AccountInputView) {}

    func accountInputViewShouldReturn(_ inputView: AccountInputView) -> Bool {
        completeInputOn(field: inputView)
        return true
    }

    func accountInputViewWillStartEditing(_ inputView: AccountInputView) {
        updateReturnButton(for: inputView)
    }

    func accountInputViewDidPaste(_: AccountInputView) {}
}

extension CreateWatchOnlyViewController: CreateWatchOnlyViewProtocol {
    func didReceiveNickname(viewModel: InputViewModelProtocol) {
        rootView.walletNameInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveSubstrateAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.substrateAddressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveSubstrateAddressInput(viewModel: InputViewModelProtocol) {
        rootView.substrateAddressInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveEVMAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.evmAddressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveEVMAddressInput(viewModel: InputViewModelProtocol) {
        rootView.evmAddressInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }

    func didReceivePreset(titles: [String]) {
        rootView.clearPresets()

        titles.forEach { title in
            let button = rootView.addPresetButton(with: title)
            button.addTarget(self, action: #selector(actionPreset), for: .touchUpInside)
        }
    }
}

extension CreateWatchOnlyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
