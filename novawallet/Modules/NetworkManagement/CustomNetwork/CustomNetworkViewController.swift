import UIKit
import Foundation_iOS

final class CustomNetworkViewController: UIViewController, ViewHolder {
    typealias RootViewType = CustomNetworkViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: CustomNetworkPresenterProtocol

    init(
        presenter: CustomNetworkPresenterProtocol,
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
        view = CustomNetworkViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.locale = selectedLocale

        setupNetworkSwitchTitles()
        setupHandlers()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }
}

// MARK: CustomNetworkViewProtocol

extension CustomNetworkViewController: CustomNetworkViewProtocol {
    func didReceiveNetworkType(_ networkType: CustomNetworkType, show: Bool) {
        show
            ? rootView.showNetworkTypeSwitch()
            : rootView.hideNetworkTypeSwitch()

        switch networkType {
        case .evm:
            rootView.showChainId()
        case .substrate:
            rootView.hideChainId()
        }
    }

    func didReceiveTitle(text: String) {
        rootView.titleLabel.text = text
    }

    func didReceiveUrl(viewModel: InputViewModelProtocol) {
        rootView.urlInput.bind(inputViewModel: viewModel)

        if viewModel.inputHandler.enabled {
            rootView.urlInput.textField.textColor = R.color.colorTextPrimary()
        } else {
            rootView.urlInput.textField.textColor = R.color.colorTextSecondary()
        }
    }

    func didReceiveName(viewModel: InputViewModelProtocol) {
        rootView.nameInput.bind(inputViewModel: viewModel)
    }

    func didReceiveCurrencySymbol(viewModel: InputViewModelProtocol) {
        rootView.currencySymbolInput.bind(inputViewModel: viewModel)
    }

    func didReceiveChainId(viewModel: InputViewModelProtocol?) {
        guard let viewModel else {
            rootView.hideChainId()

            return
        }

        rootView.showChainId()
        rootView.chainIdInput.bind(inputViewModel: viewModel)
    }

    func didReceiveBlockExplorerUrl(viewModel: InputViewModelProtocol) {
        rootView.blockExplorerUrlInput.bind(inputViewModel: viewModel)
    }

    func didReceiveCoingeckoUrl(viewModel: InputViewModelProtocol) {
        rootView.coingeckoUrlInput.bind(inputViewModel: viewModel)
    }

    func didReceiveButton(viewModel: NetworkNodeViewLayout.LoadingButtonViewModel) {
        viewModel.loading
            ? rootView.actionLoadableView.startLoading()
            : rootView.actionLoadableView.stopLoading()

        viewModel.enabled
            ? rootView.actionButton.applyEnabledStyle()
            : rootView.actionButton.applyDisabledStyle()

        rootView.actionButton.isUserInteractionEnabled = viewModel.enabled
        rootView.actionButton.imageWithTitleView?.title = viewModel.title
    }
}

// MARK: KeyboardAdoptable

extension CustomNetworkViewController: KeyboardAdoptable {
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

            if rootView.urlInput.textField.isFirstResponder {
                targetView = rootView.urlInput
            } else if rootView.nameInput.textField.isFirstResponder {
                targetView = rootView.nameInput
            } else if rootView.currencySymbolInput.textField.isFirstResponder {
                targetView = rootView.currencySymbolInput
            } else if rootView.currencySymbolInput.textField.isFirstResponder {
                targetView = rootView.currencySymbolInput
            } else if rootView.blockExplorerUrlInput.textField.isFirstResponder {
                targetView = rootView.blockExplorerUrlInput
            } else if rootView.coingeckoUrlInput.textField.isFirstResponder {
                targetView = rootView.coingeckoUrlInput
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

// MARK: Localizable

extension CustomNetworkViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        rootView.locale = selectedLocale
    }
}

// MARK: Private

private extension CustomNetworkViewController {
    func setupNetworkSwitchTitles() {
        rootView.networkTypeSwitch.titles = [
            "Substrate",
            "EVM"
        ]
    }

    func setupHandlers() {
        rootView.networkTypeSwitch.addTarget(
            self,
            action: #selector(actionSegmentChanged),
            for: .valueChanged
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.urlInput.pasteButton.addTarget(
            self,
            action: #selector(actionURLFieldPaste),
            for: .touchUpInside
        )

        rootView.urlInput.textField.addTarget(
            self,
            action: #selector(actionURLEndEditing),
            for: .editingDidEnd
        )

        let inputs = [
            rootView.urlInput,
            rootView.nameInput,
            rootView.currencySymbolInput,
            rootView.chainIdInput,
            rootView.blockExplorerUrlInput,
            rootView.coingeckoUrlInput
        ]

        let actions = [
            #selector(actionURLChanged),
            #selector(actionNameChanged),
            #selector(actionCurrencySymbolChanged),
            #selector(actionChainIdChanged),
            #selector(actionBlockExplorerURLChanged),
            #selector(actionCoingeckoURLChanged)
        ]

        zip(inputs, actions).forEach { input, action in
            input.addTarget(
                self,
                action: action,
                for: .editingChanged
            )
        }
    }

    @objc func actionURLEndEditing() {
        guard let text = rootView.urlInput.textField.text else { return }

        presenter.handle(url: text)
    }

    @objc func actionURLFieldPaste() {
        guard let text = rootView.urlInput.pasteboardService.pasteboard.string else { return }

        presenter.handle(url: text)
    }

    @objc private func actionSegmentChanged() {
        presenter.select(
            segment: .init(rawValue: rootView.networkTypeSwitch.selectedSegmentIndex)
        )
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }

    @objc func actionURLChanged() {
        let partialAddress = rootView.urlInput.textField.text ?? ""
        presenter.handlePartial(url: partialAddress)
    }

    @objc func actionNameChanged() {
        let partialSymbol = rootView.nameInput.textField.text ?? ""
        presenter.handlePartial(name: partialSymbol)
    }

    @objc func actionCurrencySymbolChanged() {
        let partialSymbol = rootView.currencySymbolInput.textField.text ?? ""
        presenter.handlePartial(currencySymbol: partialSymbol)
    }

    @objc func actionChainIdChanged() {
        let partialChainId = rootView.chainIdInput.textField.text ?? ""
        presenter.handlePartial(chainId: partialChainId)
    }

    @objc func actionBlockExplorerURLChanged() {
        let partialAddress = rootView.blockExplorerUrlInput.textField.text ?? ""
        presenter.handlePartial(blockExplorerURL: partialAddress)
    }

    @objc func actionCoingeckoURLChanged() {
        let partialAddress = rootView.coingeckoUrlInput.textField.text ?? ""
        presenter.handlePartial(coingeckoURL: partialAddress)
    }
}
