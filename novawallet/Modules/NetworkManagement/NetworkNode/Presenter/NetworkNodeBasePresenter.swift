import Foundation
import Foundation_iOS

class NetworkNodeBasePresenter {
    weak var view: NetworkNodeViewProtocol?
    let wireframe: NetworkNodeWireframeProtocol
    private let interactor: NetworkNodeBaseInteractorInputProtocol

    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    var partialURL: String?
    var partialName: String?

    var chain: ChainModel?

    init(
        interactor: NetworkNodeBaseInteractorInputProtocol,
        wireframe: NetworkNodeWireframeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
    }

    func actionConfirm() {
        fatalError("Must be overriden by subclass")
    }

    func completeButtonTitle() -> String {
        fatalError("Must be overriden by subclass")
    }

    func provideTitle() {
        fatalError("Must be overriden by subclass")
    }

    func provideButtonViewModel(loading: Bool) {
        let completed: Bool = if let partialName, let partialURL {
            !partialName.isEmpty && !partialURL.isEmpty
        } else {
            false
        }

        let title: String = if completed {
            completeButtonTitle()
        } else {
            R.string.localizable.networkNodeAddButtonEnterDetails(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        let viewModel = NetworkNodeViewLayout.LoadingButtonViewModel(
            title: title,
            enabled: completed,
            loading: loading
        )

        view?.didReceiveButton(viewModel: viewModel)
    }

    func provideURLViewModel(for _: ChainModel?) {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialURL ?? "",
            placeholder: Constants.urlPlaceholder
        )
        view?.didReceiveUrl(viewModel: inputViewModel)
    }

    func provideNameViewModel() {
        let inputViewModel = InputViewModel.createNotEmptyInputViewModel(
            for: partialName ?? "",
            placeholder: R.string.localizable.commonName(preferredLanguages: selectedLocale.rLanguages),
            spacesAllowed: true
        )
        view?.didReceiveName(viewModel: inputViewModel)
    }
}

// MARK: NetworkNodePresenterProtocol

extension NetworkNodeBasePresenter: NetworkNodePresenterProtocol {
    func setup() {
        interactor.setup()
        provideButtonViewModel(loading: false)
    }

    func handlePartial(url: String) {
        partialURL = url

        provideButtonViewModel(loading: false)
    }

    func handlePartial(name: String) {
        partialName = name

        provideButtonViewModel(loading: false)
    }

    func confirm() {
        provideButtonViewModel(loading: true)

        actionConfirm()
    }
}

// MARK: NetworkNodeBaseInteractorOutputProtocol

extension NetworkNodeBasePresenter: NetworkNodeBaseInteractorOutputProtocol {
    func didReceive(_ chain: ChainModel) {
        provideViewModel(with: chain)
    }

    func didReceive(_ error: NetworkNodeBaseInteractorError) {
        let close = R.string.localizable.commonClose(
            preferredLanguages: selectedLocale.rLanguages
        )

        let errorContent = error.toErrorContent(for: selectedLocale)

        wireframe.present(
            message: errorContent.message,
            title: errorContent.title,
            closeAction: close,
            from: view
        )

        provideButtonViewModel(loading: false)
    }
}

// MARK: Private

private extension NetworkNodeBasePresenter {
    func provideViewModel(with chain: ChainModel?) {
        guard let chain else { return }

        provideTitle()
        provideURLViewModel(for: chain)
        provideNameViewModel()
        provideChainViewModel(for: chain)
        provideButtonViewModel(loading: false)
    }

    func provideChainViewModel(for chain: ChainModel) {
        let viewModel = networkViewModelFactory.createViewModel(from: chain)
        view?.didReceiveChain(viewModel: viewModel)
    }
}

// MARK: Localizable

extension NetworkNodeBasePresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel(with: chain)
    }
}

// MARK: Constants

extension NetworkNodeBasePresenter {
    enum Constants {
        static let urlPlaceholder = "wss://"
    }
}
