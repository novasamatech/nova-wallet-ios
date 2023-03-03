import Foundation
import SoraFoundation

final class GovernanceDelegateSearchPresenter {
    weak var view: GovernanceDelegateSearchViewProtocol?
    let wireframe: GovernanceDelegateSearchWireframeProtocol
    let interactor: GovernanceDelegateSearchInteractorInputProtocol

    private(set) var delegates: [AccountAddress: GovernanceDelegateLocal] = [:]
    private(set) var metadata: [GovernanceDelegateMetadataRemote]?
    private(set) var identities: [AccountAddress: AccountIdentity] = [:]
    private(set) var remoteSearched: Set<AccountAddress> = Set()

    private(set) var searchString: String = ""

    let viewModelFactory: GovernanceDelegateViewModelFactoryProtocol
    let chain: ChainModel
    let logger: LoggerProtocol

    init(
        interactor: GovernanceDelegateSearchInteractorInputProtocol,
        wireframe: GovernanceDelegateSearchWireframeProtocol,
        viewModelFactory: GovernanceDelegateViewModelFactoryProtocol,
        initDelegates: [AccountAddress: GovernanceDelegateLocal],
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        delegates = initDelegates
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func insertNewFromClosures(
        initDelegates: [AccountAddress: GovernanceDelegateLocal],
        onChainDelegateClosure: (AccountAddress, GovernanceDelegateLocal) -> Bool,
        metadataClosure: (GovernanceDelegateMetadataRemote) -> Bool,
        identityClosure: (AccountAddress, AccountIdentity) -> Bool
    ) -> [AccountAddress: GovernanceDelegateLocal] {
        var targetDelegates = delegates.reduce(into: initDelegates) { accum, keyValue in
            let address = keyValue.key
            let delegate = keyValue.value

            guard accum[address] == nil, onChainDelegateClosure(address, delegate) else {
                return
            }

            accum[address] = delegate
        }

        targetDelegates = (metadata ?? []).reduce(into: targetDelegates) { accum, item in
            guard accum[item.address] == nil, metadataClosure(item) else {
                return
            }

            accum[item.address] = GovernanceDelegateLocal(
                stats: .init(address: item.address),
                metadata: item,
                identity: identities[item.address]
            )
        }

        return identities.reduce(into: targetDelegates) { accum, keyValue in
            let address = keyValue.key
            let identity = keyValue.value

            guard accum[address] == nil, identityClosure(address, identity) else {
                return
            }

            accum[address] = .init(
                stats: .init(address: address),
                metadata: nil,
                identity: identity
            )
        }
    }

    private func updateSearchResult() {
        guard searchString.isEmpty else {
            provideSearchResult(for: [])
            return
        }

        var targetDelegates = insertNewFromClosures(
            initDelegates: [:],
            onChainDelegateClosure: { address, _ in
                address.hasPrefix(searchString)
            },
            metadataClosure: { metadata in
                metadata.address.hasPrefix(searchString)
            },
            identityClosure: { address, _ in
                address.hasPrefix(searchString)
            }
        )

        targetDelegates = insertNewFromClosures(
            initDelegates: targetDelegates,
            onChainDelegateClosure: { _, delegate in
                delegate.displayName?.localizedCaseInsensitiveContains(searchString) == true
            },
            metadataClosure: { metadata in
                metadata.name.localizedCaseInsensitiveContains(searchString)
            },
            identityClosure: { _, identity in
                identity.displayName.localizedCaseInsensitiveContains(searchString)
            }
        )

        if
            targetDelegates[searchString] == nil,
            !remoteSearched.contains(searchString),
            let accountId = try? searchString.toAccountId(using: chain.chainFormat) {
            view?.didStartSearch()
            remoteSearched.insert(searchString)
            interactor.performDelegateSearch(accountId: accountId)
        }

        let delegates = targetDelegates.values.sorted { delegate1, delegate2 in
            if delegate1.metadata != nil, delegate2.metadata == nil {
                return true
            } else if delegate1.metadata == nil, delegate2.metadata != nil {
                return false
            } else {
                return GovernanceDelegatesOrder.delegations.isDescending(delegate1, delegate2: delegate2)
            }
        }

        provideSearchResult(for: delegates)
    }

    private func provideSearchResult(for delegates: [GovernanceDelegateLocal]) {
        let viewModels = delegates.map { delegate in
            viewModelFactory.createAnyDelegateViewModel(
                from: delegate,
                chain: chain,
                locale: selectedLocale
            )
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension GovernanceDelegateSearchPresenter: GovernanceDelegateSearchPresenterProtocol {
    func setup() {
        interactor.setup()

        updateSearchResult()
    }

    func search(for textEntry: String) {
        searchString = textEntry

        updateSearchResult()
    }
}

extension GovernanceDelegateSearchPresenter: GovernanceDelegateSearchInteractorOutputProtocol {
    func didReceiveIdentity(_ identity: AccountIdentity?, for accountId: AccountId) {
        guard let address = try? accountId.toAddress(using: chain.chainFormat) else {
            return
        }

        identities[address] = identity

        view?.didStopSearch()

        updateSearchResult()
    }

    func didReceiveDelegates(_ delegates: [AccountAddress: GovernanceDelegateLocal]) {
        self.delegates = delegates

        updateSearchResult()
    }

    func didReceiveMetadata(_ metadata: [GovernanceDelegateMetadataRemote]?) {
        self.metadata = metadata

        updateSearchResult()
    }

    func didReceiveError(_ error: GovernanceDelegateSearchError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .delegateFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshDelegates()
            }
        case let .identityFetchFailed(accountId, _):
            view?.didStopSearch()

            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.performDelegateSearch(accountId: accountId)
            }
        case .metadataSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        }
    }
}

extension GovernanceDelegateSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateSearchResult()
        }
    }
}
