import Foundation
import Foundation_iOS

final class GovernanceDelegateSearchPresenter {
    weak var view: GovernanceDelegateSearchViewProtocol?
    let wireframe: GovernanceDelegateSearchWireframeProtocol
    let interactor: GovernanceDelegateSearchInteractorInputProtocol

    private(set) var delegates: [AccountAddress: GovernanceDelegateLocal] = [:]
    private(set) var yourDelegations: [AccountAddress: GovernanceYourDelegationGroup] = [:]
    private(set) var metadata: [GovernanceDelegateMetadataRemote]?
    private(set) var identities: [AccountAddress: AccountIdentity] = [:]
    private(set) var noIdentities: Set<AccountAddress> = Set()
    private(set) var remoteSearched: Set<AccountAddress> = Set()

    private(set) var searchString: String = ""

    let anyDelegationViewModelFactory: GovernanceDelegateViewModelFactoryProtocol
    let yourDelegationsViewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol
    let chain: ChainModel
    let logger: LoggerProtocol

    init(
        interactor: GovernanceDelegateSearchInteractorInputProtocol,
        wireframe: GovernanceDelegateSearchWireframeProtocol,
        anyDelegationViewModelFactory: GovernanceDelegateViewModelFactoryProtocol,
        yourDelegationsViewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol,
        initDelegates: [AccountAddress: GovernanceDelegateLocal],
        initDelegations: [AccountAddress: GovernanceYourDelegationGroup],
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.anyDelegationViewModelFactory = anyDelegationViewModelFactory
        self.yourDelegationsViewModelFactory = yourDelegationsViewModelFactory
        delegates = initDelegates
        yourDelegations = initDelegations
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func deriveDelegate(from address: AccountAddress) -> GovernanceDelegateLocal {
        if let delegate = delegates[address] {
            return delegate
        }

        let metadataItem = metadata?.first(where: { $0.address == address })

        return .init(stats: .init(address: address), metadata: metadataItem, identity: identities[address])
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
        guard !searchString.isEmpty else {
            provideInitialSearchResult()
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

        let optAccountId = try? searchString.toAccountId(using: chain.chainFormat)

        if
            targetDelegates[searchString] == nil,
            !remoteSearched.contains(searchString),
            let accountId = optAccountId {
            view?.didStartSearch()
            remoteSearched.insert(searchString)
            interactor.performDelegateSearch(accountId: accountId)
        }

        if targetDelegates[searchString] == nil, optAccountId != nil, noIdentities.contains(searchString) {
            targetDelegates[searchString] = .init(
                stats: .init(address: searchString),
                metadata: nil,
                identity: nil
            )
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
            if let delegation = yourDelegations[delegate.stats.address] {
                let updatedDelegation = GovernanceYourDelegationGroup(
                    delegateModel: delegate,
                    delegations: delegation.delegations,
                    tracks: delegation.tracks
                )

                if
                    let viewModel = yourDelegationsViewModelFactory.createYourDelegateViewModel(
                        from: updatedDelegation,
                        chain: chain,
                        locale: selectedLocale
                    ) {
                    return AddDelegationViewModel.yourDelegate(viewModel)
                }
            }

            let viewModel = anyDelegationViewModelFactory.createAnyDelegateViewModel(
                from: delegate,
                chain: chain,
                locale: selectedLocale
            )

            return AddDelegationViewModel.delegate(viewModel)
        }

        if !viewModels.isEmpty {
            let title = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonSearchResultsNumber(viewModels.count)

            view?.didReceive(
                viewModel: .found(title: .init(title: title), items: viewModels)
            )
        } else {
            view?.didReceive(viewModel: .notFound)
        }
    }

    private func provideInitialSearchResult() {
        view?.didReceive(viewModel: .start)
    }
}

extension GovernanceDelegateSearchPresenter: GovernanceDelegateSearchPresenterProtocol {
    func setup() {
        interactor.setup()

        updateSearchResult()
    }

    func presentResult(for address: AccountAddress) {
        let delegate = deriveDelegate(from: address)

        wireframe.showInfo(from: view, delegate: delegate)
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

        if identity == nil {
            noIdentities.insert(address)
        }

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
        case .metadataSubscriptionFailed, .blockSubscriptionFailed:
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
