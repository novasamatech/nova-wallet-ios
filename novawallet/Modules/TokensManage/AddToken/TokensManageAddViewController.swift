import UIKit
import Foundation_iOS

final class TokensManageAddViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageAddViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: TokensManageAddPresenterProtocol

    init(presenter: TokensManageAddPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensManageAddViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        setupTextFields()

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

    private func setupTextFields() {
        rootView.addressInputView.textField.applyLineBreakMode(.byTruncatingMiddle)
        rootView.addressInputView.textField.returnKeyType = .done
        rootView.addressInputView.textField.keyboardType = .asciiCapable

        rootView.symbolInputView.textField.returnKeyType = .done
        rootView.symbolInputView.textField.keyboardType = .asciiCapable

        rootView.decimalsInputView.textField.returnKeyType = .done
        rootView.decimalsInputView.textField.keyboardType = .decimalPad

        rootView.priceIdInputView.textField.returnKeyType = .done
        rootView.priceIdInputView.textField.keyboardType = .URL
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionAdd),
            for: .touchUpInside
        )

        rootView.addressInputView.addTarget(
            self,
            action: #selector(actionContractAddressChanged),
            for: .editingChanged
        )

        rootView.symbolInputView.addTarget(
            self,
            action: #selector(actionSymbolChanged),
            for: .editingChanged
        )

        rootView.decimalsInputView.addTarget(
            self,
            action: #selector(actionDecimalsChanged),
            for: .editingChanged
        )

        rootView.priceIdInputView.addTarget(
            self,
            action: #selector(actionPriceIdChanged),
            for: .editingChanged
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.addTokenTitle()
        rootView.addressTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonContractAddress()
        rootView.symbolTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonTokenSymbol()
        rootView.decimalsTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonTokenDecimals()
        rootView.priceIdTitleLabel.text = R.string(preferredLanguages: languages).localizable.addTokenPriceTitle()

        rootView.addressInputView.locale = selectedLocale
        rootView.priceIdInputView.locale = selectedLocale

        updateActionButton()
    }

    private func updateActionButton() {
        let languages = selectedLocale.rLanguages

        if !rootView.addressInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: languages
            ).localizable.addTokenEnterContractAddress()

            return
        }

        if !rootView.symbolInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: languages
            ).localizable.addTokenEnterSymbol()

            return
        }

        if !rootView.decimalsInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: languages
            ).localizable.addTokenEnterDecimals()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: languages
        ).localizable.addTokenAction()
    }

    private func applyPlaceholder(_ placeholder: String, inputView: TextInputView) {
        let placeholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        inputView.textField.attributedPlaceholder = placeholder
    }

    @objc func actionAdd() {
        presenter.confirmTokenAdd()
    }

    @objc func actionContractAddressChanged() {
        let partialAddress = rootView.addressInputView.textField.text ?? ""
        presenter.handlePartial(address: partialAddress)

        updateActionButton()
    }

    @objc func actionSymbolChanged() {
        let partialSymbol = rootView.symbolInputView.textField.text ?? ""
        presenter.handlePartial(symbol: partialSymbol)

        updateActionButton()
    }

    @objc func actionDecimalsChanged() {
        let partialDecimals = rootView.decimalsInputView.textField.text ?? ""
        presenter.handlePartial(decimals: partialDecimals)

        updateActionButton()
    }

    @objc func actionPriceIdChanged() {
        let partialPriceIdUrl = rootView.priceIdInputView.textField.text ?? ""
        presenter.handlePartial(priceIdUrl: partialPriceIdUrl)

        updateActionButton()
    }
}

extension TokensManageAddViewController: KeyboardAdoptable {
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

            if rootView.addressInputView.textField.isFirstResponder {
                targetView = rootView.addressInputView
            } else if rootView.symbolInputView.textField.isFirstResponder {
                targetView = rootView.symbolInputView
            } else if rootView.decimalsInputView.textField.isFirstResponder {
                targetView = rootView.decimalsInputView
            } else if rootView.priceIdInputView.textField.isFirstResponder {
                targetView = rootView.priceIdInputView
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

extension TokensManageAddViewController: TokensManageAddViewProtocol {
    func didReceiveAddress(viewModel: InputViewModelProtocol) {
        rootView.addressInputView.bind(inputViewModel: viewModel)

        applyPlaceholder(viewModel.placeholder, inputView: rootView.addressInputView)

        updateActionButton()
    }

    func didReceiveSymbol(viewModel: InputViewModelProtocol) {
        rootView.symbolInputView.bind(inputViewModel: viewModel)

        applyPlaceholder(viewModel.placeholder, inputView: rootView.symbolInputView)

        updateActionButton()
    }

    func didReceiveDecimals(viewModel: InputViewModelProtocol) {
        rootView.decimalsInputView.bind(inputViewModel: viewModel)

        applyPlaceholder(viewModel.placeholder, inputView: rootView.decimalsInputView)

        updateActionButton()
    }

    func didReceivePriceId(viewModel: InputViewModelProtocol) {
        rootView.priceIdInputView.bind(inputViewModel: viewModel)

        applyPlaceholder(viewModel.placeholder, inputView: rootView.priceIdInputView)

        updateActionButton()
    }
}

extension TokensManageAddViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension TokensManageAddViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
