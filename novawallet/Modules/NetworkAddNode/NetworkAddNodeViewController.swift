import UIKit
import SoraFoundation

final class NetworkAddNodeViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkAddNodeViewLayout

    let presenter: NetworkAddNodePresenterProtocol

    init(
        presenter: NetworkAddNodePresenterProtocol,
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
        view = NetworkAddNodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        rootView.locale = selectedLocale

        setupHandlers()
        updateActionButton()
    }
}

// MARK: NetworkAddNodeViewProtocol

extension NetworkAddNodeViewController: NetworkAddNodeViewProtocol {
    func didReceiveUrl(viewModel: InputViewModelProtocol) {
        rootView.urlInput.bind(inputViewModel: viewModel)

        updateActionButton()
    }

    func didReceiveName(viewModel: InputViewModelProtocol) {
        rootView.nameInput.bind(inputViewModel: viewModel)

        updateActionButton()
    }
    
    func setLoading(_ loading: Bool) {
        loading
            ? rootView.actionLoadableView.startLoading()
            : rootView.actionLoadableView.stopLoading()
    }
}

// MARK: Localizable

extension NetworkAddNodeViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        rootView.locale = selectedLocale
    }
}

// MARK: Private

private extension NetworkAddNodeViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionAddNode),
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

    @objc func actionAddNode() {
        presenter.confirmAddNode()
    }

    @objc func actionURLChanged() {
        let partialAddress = rootView.urlInput.textField.text ?? ""
        presenter.handlePartial(url: partialAddress)

        updateActionButton()
    }

    @objc func actionNameChanged() {
        let partialSymbol = rootView.nameInput.textField.text ?? ""
        presenter.handlePartial(name: partialSymbol)

        updateActionButton()
    }

    private func updateActionButton() {
        let languages = selectedLocale.rLanguages

        if rootView.urlInput.completed, rootView.nameInput.completed {
            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.isUserInteractionEnabled = true

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.networkNodeAddButtonAdd(
                preferredLanguages: languages
            )
        } else {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.networkNodeAddButtonEnterDetails(
                preferredLanguages: languages
            )
        }
    }
}
