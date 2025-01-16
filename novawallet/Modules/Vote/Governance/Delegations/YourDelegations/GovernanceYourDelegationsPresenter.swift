import Foundation
import Foundation_iOS

final class GovernanceYourDelegationsPresenter {
    weak var view: GovernanceYourDelegationsViewProtocol?
    let wireframe: GovernanceYourDelegationsWireframeProtocol
    let interactor: GovernanceYourDelegationsInteractorInputProtocol

    let viewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol
    let chain: ChainModel

    private var delegations: [TrackIdLocal: ReferendumDelegatingLocal]?
    private var delegates: [GovernanceDelegateLocal]?
    private var tracks: [GovernanceTrackInfoLocal]?
    private var groups: [GovernanceYourDelegationGroup]?
    private var metadata: [GovernanceDelegateMetadataRemote]?

    let logger: LoggerProtocol

    init(
        interactor: GovernanceYourDelegationsInteractorInputProtocol,
        wireframe: GovernanceYourDelegationsWireframeProtocol,
        chain: ChainModel,
        viewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard
            let delegations = delegations,
            let delegates = delegates,
            let tracks = tracks else {
            view?.didReceive(viewModels: [])
            return
        }

        let groups = GovernanceYourDelegationGroup.createGroups(
            from: delegates,
            delegations: delegations,
            tracks: tracks,
            metadata: metadata,
            chain: chain
        )

        self.groups = groups

        let viewModels = groups.compactMap {
            viewModelFactory.createYourDelegateViewModel(
                from: $0,
                chain: chain,
                locale: selectedLocale
            )
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension GovernanceYourDelegationsPresenter: GovernanceYourDelegationsPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func addDelegation() {
        wireframe.showAddDelegation(from: view, yourDelegations: groups ?? [])
    }

    func selectDelegate(for address: AccountAddress) {
        guard let group = groups?.first(where: { $0.delegateModel.stats.address == address }) else {
            return
        }

        wireframe.showDelegateInfo(from: view, delegate: group.delegateModel)
    }
}

extension GovernanceYourDelegationsPresenter: GovernanceYourDelegationsInteractorOutputProtocol {
    func didReceiveDelegations(_ delegations: [TrackIdLocal: ReferendumDelegatingLocal]) {
        self.delegations = delegations

        updateView()
    }

    func didReceiveDelegates(_ delegates: [GovernanceDelegateLocal]) {
        self.delegates = delegates

        updateView()
    }

    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal]) {
        self.tracks = tracks

        updateView()
    }

    func didReceiveMetadata(_ metadata: [GovernanceDelegateMetadataRemote]) {
        self.metadata = metadata

        updateView()
    }

    func didReceiveError(_ error: GovernanceYourDelegationsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .blockTimeFetchFailed, .blockSubscriptionFailed, .delegationsSubscriptionFailed,
             .metadataSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .delegatesFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshDelegates()
            }
        case .tracksFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshTracks()
            }
        }
    }
}

extension GovernanceYourDelegationsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
