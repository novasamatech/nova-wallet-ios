import UIKit
import SoraFoundation

final class CustomNetworkViewController: UIViewController, ViewHolder {
    typealias RootViewType = CustomNetworkViewLayout

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
        
        setupHandlers()
        presenter.setup()
    }
}

// MARK: CustomNetworkViewProtocol

extension CustomNetworkViewController: CustomNetworkViewProtocol {
    func didReceiveTitle(text: String) {
        rootView.titleLabel.text = text
    }
    
    func didReceiveUrl(viewModel: InputViewModelProtocol) {
        rootView.urlInput.bind(inputViewModel: viewModel)
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

// MARK: Localizable

extension CustomNetworkViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        rootView.locale = selectedLocale
    }
}

// MARK: Private

private extension CustomNetworkViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
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
        presenter.handlePartial(currencySymbol: partialChainId)
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
