import Foundation
import SoraFoundation
import RobinHood
import BigInt

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol
    private var delegates: [AccountAddress: GovernanceDelegateLocal] = [:]
    let numberFormatter = NumberFormatter.quantity.localizableResource()
    var chain: ChainModel?
    let lastVotedDays: Int = 30

    init(
        interactor: AddDelegationInteractorInputProtocol,
        wireframe: AddDelegationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let chainAsset = chain?.utilityAsset() else {
            return
        }

        let viewModel = delegates.values.map { convert(delegate: $0, chainAsset: chainAsset) }
        view?.update(viewModel: viewModel)
    }

    private func convert(
        delegate: GovernanceDelegateLocal,
        chainAsset: AssetModel
    ) -> DelegateTableViewCell.Model {
        let icon = delegate.metadata.map { RemoteImageViewModel(url: $0.image) }
        let numberFormatter = numberFormatter.value(for: selectedLocale)
        let delegations = numberFormatter.string(from: NSNumber(value: delegate.stats.delegationsCount))
        let totalVotes = formatVotes(
            votesInPlank: delegate.stats.delegatedVotes,
            precision: chainAsset.precision
        )
        let lastVotes = numberFormatter.string(from: NSNumber(value: delegate.stats.recentVotes))

        return DelegateTableViewCell.Model(
            id: delegate.identifier,
            icon: icon,
            name: delegate.metadata?.name ?? delegate.stats.address,
            type: delegate.metadata.map { $0.isOrganization ? .organization : .individual },
            description: delegate.metadata?.shortDescription ?? "",
            delegationsTitle: DelegatesSortOption.delegations.value(for: selectedLocale),
            delegations: delegations,
            votesTitle: DelegatesSortOption.delegatedVotes.value(for: selectedLocale),
            votes: totalVotes,
            lastVotesTitle: DelegatesSortOption.lastVoted(days: lastVotedDays).value(for: selectedLocale),
            lastVotes: lastVotes
        )
    }

    private func formatVotes(votesInPlank: BigUInt, precision: UInt16) -> String {
        guard let votes = Decimal.fromSubstrateAmount(
            votesInPlank,
            precision: Int16(precision)
        ) else {
            return ""
        }
        return numberFormatter.value(for: selectedLocale).stringFromDecimal(votes) ?? ""
    }
}

extension AddDelegationPresenter: AddDelegationPresenterProtocol {
    func setup() {
        interactor.setup()
        view?.update(showValue: .all)
        view?.update(sortValue: .delegations)
    }

    func selectDelegate(_: DelegateTableViewCell.Model) {}

    func closeBanner() {}

    func showAddDelegateInformation() {}

    func showSortOptions() {}

    func showFilters() {}
}

extension AddDelegationPresenter: AddDelegationInteractorOutputProtocol {
    func didReceiveDelegates(changes: [DataProviderChange<GovernanceDelegateLocal>]) {
        delegates = changes.mergeToDict(delegates)
        updateView()
    }

    func didReceive(chain: ChainModel) {
        self.chain = chain
        updateView()
    }
}

extension AddDelegationPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
