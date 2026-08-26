import Foundation
import Foundation_iOS

final class SubtensorSubnetSelectPresenter {
    weak var view: SubtensorSubnetSelectViewProtocol?
    let wireframe: SubtensorSubnetSelectWireframeProtocol
    let interactor: SubnetSelectInteractorInputProtocol
    let viewModelFactory: SubtensorSubnetViewModelFactoryProtocol
    let logger: LoggerProtocol

    weak var delegate: SubtensorSubnetSelectDelegate?

    /// the take of the hotkey the flow will actually stake with; the chain-wide
    /// default is only a fallback until it is known
    let preferredTake: UInt16?

    private(set) var subnetsInfo: SubtensorSubnetsInfo?
    private(set) var defaultTake: UInt16?
    private(set) var query: String = ""

    init(
        interactor: SubnetSelectInteractorInputProtocol,
        wireframe: SubtensorSubnetSelectWireframeProtocol,
        viewModelFactory: SubtensorSubnetViewModelFactoryProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        preferredTake: UInt16?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        self.preferredTake = preferredTake
        self.logger = logger

        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetSelectPresenter {
    func provideViewModels() {
        guard let subnetsInfo else {
            view?.didReceive(viewModels: [])
            return
        }

        let viewModels = viewModelFactory.createViewModels(
            from: subnetsInfo,
            defaultTake: preferredTake ?? defaultTake,
            query: query,
            locale: selectedLocale
        )

        view?.didReceive(viewModels: viewModels)
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetSelectPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func search(query: String) {
        self.query = query

        provideViewModels()
    }

    func select(viewModel: SubtensorSubnetSelectViewModel) {
        delegate?.didSelectStakeTarget(viewModel.target)

        wireframe.complete(from: view)
    }
}

extension SubtensorSubnetSelectPresenter: SubnetSelectInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo) {
        subnetsInfo = info

        provideViewModels()
    }

    func didReceiveDefaultTake(_ take: UInt16) {
        defaultTake = take

        provideViewModels()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Subnets fetch failed: \(error)")

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.refresh()
        }
    }
}

extension SubtensorSubnetSelectPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModels()
        }
    }
}
