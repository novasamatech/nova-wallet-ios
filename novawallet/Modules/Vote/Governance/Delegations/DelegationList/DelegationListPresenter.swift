import Foundation
import Foundation_iOS
import BigInt

final class DelegationListPresenter {
    weak var view: VotesViewProtocol?
    let wireframe: DelegationListWireframeProtocol
    let interactor: DelegationListInteractorInputProtocol
    let chain: ChainModel
    let stringFactory: DelegationsDisplayStringFactoryProtocol
    let logger: LoggerProtocol

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()
    private var delegations: GovernanceOffchainDelegationsLocal?

    init(
        interactor: DelegationListInteractorInputProtocol,
        chain: ChainModel,
        stringFactory: DelegationsDisplayStringFactoryProtocol,
        wireframe: DelegationListWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.chain = chain
        self.stringFactory = stringFactory
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private var title: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.delegationsDelegations()
        }
    }

    private var emptyStateTitle: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.delegationsListEmpty()
        }
    }

    private func createViewModel(
        delegator: AccountAddress,
        delegations: [GovernanceOffchainDelegation],
        identites: [AccountId: AccountIdentity]
    ) -> (votes: BigUInt, viewModel: VotesViewModel)? {
        guard let accountId = try? delegator.toAccountId(),
              !delegations.isEmpty else {
            return nil
        }

        let displayAddressViewModel: DisplayAddressViewModel
        if let displayName = identites[accountId]?.displayName {
            let displayAddress = DisplayAddress(address: delegator, username: displayName)
            displayAddressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
        } else {
            displayAddressViewModel = displayAddressFactory.createViewModel(from: delegator)
        }

        let votes = delegations.reduce(into: 0) {
            $0 += ($1.power.conviction.votes(for: $1.power.balance) ?? 0)
        }
        let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: selectedLocale)

        let details: String?
        if delegations.count > 1 {
            details = stringFactory.createVotesDetailsInMultipleTracks(
                count: delegations.count,
                locale: selectedLocale
            )
        } else {
            let amountInPlank = delegations[0].power.balance
            details = stringFactory.createVotesDetails(
                from: amountInPlank,
                conviction: delegations[0].power.conviction.decimalValue,
                chain: chain,
                locale: selectedLocale
            )
        }

        let viewModel = VotesViewModel(
            displayAddress: displayAddressViewModel,
            votes: votesString ?? "",
            votesDetails: details ?? ""
        )
        return (votes: votes, viewModel: viewModel)
    }

    private func updateView() {
        guard let delegations = delegations else {
            return
        }
        let delegatorDelegations = Dictionary(
            grouping: delegations.model,
            by: { $0.delegator }
        )
        let viewModels = delegatorDelegations.compactMap {
            createViewModel(
                delegator: $0.key,
                delegations: $0.value,
                identites: delegations.identities
            )
        }.sorted(by: { $0.votes > $1.votes }).map(\.viewModel)

        view?.didReceiveViewModels(.loaded(value: viewModels))
    }
}

extension DelegationListPresenter: DelegationListPresenterProtocol {
    func setup() {
        interactor.setup()
        view?.didReceiveEmptyView(title: emptyStateTitle)
        view?.didReceive(title: title)
        view?.didReceiveViewModels(.loading)
        view?.didReceiveRefreshState(isAvailable: true)
    }

    func select(viewModel: VotesViewModel) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: viewModel.displayAddress.address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func refresh() {
        interactor.refresh()
        view?.didReceiveViewModels(.loading)
    }
}

extension DelegationListPresenter: DelegationListInteractorOutputProtocol {
    func didReceive(delegations: GovernanceOffchainDelegationsLocal) {
        self.delegations = delegations
        updateView()
    }

    func didReceive(error: DelegationListError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .fetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refresh()
            }
        }
    }
}

extension DelegationListPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
