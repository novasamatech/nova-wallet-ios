import UIKit
import Foundation_iOS

final class NetworkNodeViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkNodeViewLayout

    let presenter: NetworkNodePresenterProtocol

    init(
        presenter: NetworkNodePresenterProtocol,
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
        view = NetworkNodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        rootView.locale = selectedLocale

        setupHandlers()
    }
}

// MARK: NetworkNodeViewProtocol

extension NetworkNodeViewController: NetworkNodeViewProtocol {
    func didReceiveUrl(viewModel: InputViewModelProtocol) {
        rootView.urlInput.bind(inputViewModel: viewModel)
    }

    func didReceiveName(viewModel: InputViewModelProtocol) {
        rootView.nameInput.bind(inputViewModel: viewModel)
    }

    func didReceiveChain(viewModel: NetworkViewModel) {
        rootView.chainView.bind(viewModel: viewModel)
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

    func didReceiveTitle(text: String) {
        rootView.titleLabel.text = text
    }
}

// MARK: Localizable

extension NetworkNodeViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        rootView.locale = selectedLocale
    }
}

// MARK: Private

private extension NetworkNodeViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.urlInput.addTarget(
            self,
            action: #selector(actionURLChanged),
            for: .editingChanged
        )

        rootView.nameInput.addTarget(
            self,
            action: #selector(actionNameChanged),
            for: .editingChanged
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
}
