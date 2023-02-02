import Foundation
import SoraFoundation

import BigInt
protocol DelegationsDisplayStringFactoryProtocol: ReferendumDisplayStringFactoryProtocol {
    func createVotesDetailsInMultipleTracks(count: Int, locale: Locale) -> String?
}

final class DelegationsDisplayStringFactory: DelegationsDisplayStringFactoryProtocol {
    let referendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol

    init(referendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol) {
        self.referendumDisplayStringFactory = referendumDisplayStringFactory
    }

    func createVotesDetailsInMultipleTracks(count: Int, locale _: Locale) -> String? {
        "Across \(count) tracks"
    }

    func createVotesValue(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        referendumDisplayStringFactory.createVotesValue(from: votes, chain: chain, locale: locale)
    }

    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        referendumDisplayStringFactory.createVotes(from: votes, chain: chain, locale: locale)
    }

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain:
        ChainModel,
        locale: Locale
    ) -> String? {
        referendumDisplayStringFactory.createVotesDetails(
            from: amount,
            conviction: conviction,
            chain: chain,
            locale: locale
        )
    }
}

final class DelegationListPresenter {
    weak var view: VotesViewProtocol?
    let wireframe: DelegationListWireframeProtocol
    let interactor: DelegationListInteractorInputProtocol
    let chain: ChainModel
    let stringFactory: DelegationsDisplayStringFactoryProtocol
    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(
        interactor: DelegationListInteractorInputProtocol,
        chain: ChainModel,
        stringFactory: DelegationsDisplayStringFactoryProtocol,
        wireframe: DelegationListWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.chain = chain
        self.stringFactory = stringFactory
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private var title: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string.localizable.delegationsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    private var emptyStateTitle: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string.localizable.delegationsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    private func updateView() {}

    private func createViewModel(
        delegator: AccountAddress,
        delegations: [GovernanceOffchainDelegation],
        identites: [AccountAddress: AccountIdentity]
    ) -> VotesViewModel? {
        let displayAddressViewModel: DisplayAddressViewModel
        let address = delegator

        if let displayName = identites[address]?.displayName {
            let displayAddress = DisplayAddress(address: address, username: displayName)
            displayAddressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
        } else {
            displayAddressViewModel = displayAddressFactory.createViewModel(from: address)
        }

        guard !delegations.isEmpty else {
            return nil
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

        return VotesViewModel(
            displayAddress: displayAddressViewModel,
            votes: votesString ?? "",
            preConviction: details ?? ""
        )
    }
}

extension DelegationListPresenter: DelegationListPresenterProtocol {
    func select(viewModel _: VotesViewModel) {}

    func setup() {
        interactor.setup()
        view?.didReceiveEmptyView(title: title)
        view?.didReceive(title: emptyStateTitle)
        view?.didReceiveViewModels(.loading)
    }
}

extension DelegationListPresenter: DelegationListInteractorOutputProtocol {
    func didReceive(delegations: [AccountAddress: [GovernanceOffchainDelegation]]) {
        let viewModels = delegations.compactMap {
            createViewModel(
                delegator: $0.key,
                delegations: $0.value,
                identites: [:]
            )
        }

        view?.didReceiveViewModels(.loaded(value: viewModels))
    }

    // TODO:
    func didReceive(error: DelegationListError) {
        print(error.localizedDescription)
    }
}

extension DelegationListPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
