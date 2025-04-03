import Foundation
import Foundation_iOS

final class DelegationReferendumVotersPresenter {
    weak var view: DelegationReferendumVotersViewProtocol?
    let wireframe: DelegationReferendumVotersWireframeProtocol
    let interactor: DelegationReferendumVotersInteractorInputProtocol
    let viewModelFactory: DelegationReferendumVotersViewModelFactoryProtocol
    let votersType: ReferendumVotersType
    let chain: ChainModel
    let logger: LoggerProtocol

    private var voters: ReferendumVoterLocals?

    init(
        interactor: DelegationReferendumVotersInteractorInputProtocol,
        wireframe: DelegationReferendumVotersWireframeProtocol,
        viewModelFactory: DelegationReferendumVotersViewModelFactoryProtocol,
        votersType: ReferendumVotersType,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.votersType = votersType
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let voters = voters else {
            return
        }

        let viewModels = viewModelFactory.createViewModel(
            voters: voters,
            type: votersType,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: .loaded(value: viewModels))
    }

    private var title: LocalizableResource<String> {
        switch votersType {
        case .ayes:
            return LocalizableResource { locale in
                R.string.localizable.govVotersAye(preferredLanguages: locale.rLanguages)
            }

        case .nays:
            return LocalizableResource { locale in
                R.string.localizable.govVotersNay(preferredLanguages: locale.rLanguages)
            }
        case .abstains:
            return LocalizableResource { locale in
                R.string.localizable.govVotersAbstain(preferredLanguages: locale.rLanguages)
            }
        }
    }
}

extension DelegationReferendumVotersPresenter: DelegationReferendumVotersPresenterProtocol {
    func setup() {
        interactor.setup()
        view?.didReceive(title: title.value(for: selectedLocale))
        view?.didReceive(viewModel: .loading)
    }

    func select(address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }
}

extension DelegationReferendumVotersPresenter: DelegationReferendumVotersInteractorOutputProtocol {
    func didReceive(error: DelegationReferendumVotersError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .fetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refresh()
            }
        }
    }

    func didReceive(voters: ReferendumVoterLocals) {
        self.voters = voters
        updateView()
    }
}

extension DelegationReferendumVotersPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
            view?.didReceive(title: title.value(for: selectedLocale))
        }
    }
}
