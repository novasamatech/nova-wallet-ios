import Foundation
import SoraFoundation
import RobinHood
import BigInt

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol
    private var delegators: [String: DelegateMetadataLocal] = [:]
    let numberFormatter = NumberFormatter.quantity.localizableResource()
    var chain: ChainModel?

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

        let viewModel = delegators.values.map { convertMetadata($0, chainAsset: chainAsset) }
        view?.update(viewModel: viewModel)
    }

    func convertMetadata(_ delegateMetadata: DelegateMetadataLocal, chainAsset: AssetModel) -> DelegateTableViewCell.Model {
        let url = delegateMetadata.profileImageUrl
            .map { RemoteImageViewModel(url: URL(string: $0)!) }

        return DelegateTableViewCell.Model(
            id: delegateMetadata.identifier,
            icon: url,
            name: delegateMetadata.name,
            type: delegateMetadata.isOrganization ? .organization : .individual,
            description: delegateMetadata.shortDescription,
            delegations: delegateMetadata.stats.map { self.numberFormatter.value(for: self.selectedLocale).string(from: NSNumber(value: $0.delegations)) ?? "" },
            votes: delegateMetadata.stats.map { formatVotes(
                votesInPlank: $0.delegatedVotesInPlank,
                precision: chainAsset.precision
            ) },
            lastVotes: delegateMetadata.stats.map { self.numberFormatter.value(for: self.selectedLocale).string(from: NSNumber(value: $0.recentVotes)) ?? "" }
        )
    }

    func formatVotes(votesInPlank: BigUInt, precision: UInt16) -> String {
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
        view?.update(showValue: "All accounts")
        view?.update(sortValue: "Delegations")
    }

    func selectDelegate(_: DelegateTableViewCell.Model) {}

    func closeBanner() {}

    func showAddDelegateInformation() {}

    func showSortOptions() {}

    func showFilters() {}
}

extension AddDelegationPresenter: AddDelegationInteractorOutputProtocol {
    func didReceive(delegatorsChanges: [DataProviderChange<DelegateMetadataLocal>]) {
        delegators = delegatorsChanges.mergeToDict(delegators)
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
