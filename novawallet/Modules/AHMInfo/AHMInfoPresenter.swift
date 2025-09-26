import Foundation
import Foundation_iOS
import BigInt

final class AHMInfoPresenter: BannersModuleInputOwnerProtocol {
    weak var view: AHMInfoViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    private let wireframe: AHMInfoWireframeProtocol
    private let interactor: AHMInfoInteractorInputProtocol
    private let viewModelFactory: AHMInfoViewModelFactoryProtocol
    private let remoteData: AHMRemoteData
    private let localizationManager: LocalizationManagerProtocol

    private var sourceChain: ChainModel?
    private var destinationChain: ChainModel?

    init(
        interactor: AHMInfoInteractorInputProtocol,
        wireframe: AHMInfoWireframeProtocol,
        viewModelFactory: AHMInfoViewModelFactoryProtocol,
        remoteData: AHMRemoteData,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.remoteData = remoteData
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        guard
            let sourceChain = sourceChain,
            let destinationChain = destinationChain
        else { return }

        let viewModel = viewModelFactory.createViewModel(
            from: remoteData,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            bannerState: bannersModule?.bannersState ?? .unavailable,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - AHMInfoPresenterProtocol

extension AHMInfoPresenter: AHMInfoPresenterProtocol {
    func setup() {
        interactor.setup()

        guard bannersModule?.locale != localizationManager.selectedLocale else { return }

        bannersModule?.updateLocale(localizationManager.selectedLocale)
    }

    func actionGotIt() {
        wireframe.complete(from: view)
    }

    func actionLearnMore() {
        guard let view else { return }

        wireframe.showWeb(
            url: remoteData.wikiURL,
            from: view,
            style: .automatic
        )
    }
}

// MARK: - AHMInfoInteractorOutputProtocol

extension AHMInfoPresenter: AHMInfoInteractorOutputProtocol {
    func didReceive(sourceChain: ChainModel) {
        self.sourceChain = sourceChain
        provideViewModel()
    }

    func didReceive(destinationChain: ChainModel) {
        self.destinationChain = destinationChain
        provideViewModel()
    }
}

// MARK: - BannersModuleOutputProtocol

extension AHMInfoPresenter: BannersModuleOutputProtocol {
    func didReceiveBanners(state _: BannersState) {
        provideViewModel()
    }

    func didUpdateContent(state _: BannersState) {
        provideViewModel()
    }

    func didReceive(_ error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: - Localizable

extension AHMInfoPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
            bannersModule?.updateLocale(localizationManager.selectedLocale)
        }
    }
}
