import Foundation
import SoraFoundation
import RobinHood
import BigInt

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol
    let numberFormatter = NumberFormatter.quantity.localizableResource()
    var chain: ChainModel?
    let lastVotedDays: Int = 30
    private var delegates: [AccountAddress: GovernanceDelegateLocal] = [:]
    private var selectedFilter = GovernanceDelegatesFilter.all
    private var selectedOrder = GovernanceDelegatesOrder.delegations
    private var shownPickerDelegate: ModalPickerViewControllerDelegate?

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

        let viewModels = delegates.values.map { convert(delegate: $0, chainAsset: chainAsset) }
        view?.didReceive(delegateViewModels: viewModels)
    }

    private func convert(
        delegate: GovernanceDelegateLocal,
        chainAsset: AssetModel
    ) -> GovernanceDelegateTableViewCell.Model {
        let icon = delegate.metadata.map { RemoteImageViewModel(url: $0.image) }
        let numberFormatter = numberFormatter.value(for: selectedLocale)
        let delegations = numberFormatter.string(from: NSNumber(value: delegate.stats.delegationsCount))
        let totalVotes = formatVotes(
            votesInPlank: delegate.stats.delegatedVotes,
            precision: chainAsset.precision
        )
        let lastVotes = numberFormatter.string(from: NSNumber(value: delegate.stats.recentVotes))

        return GovernanceDelegateTableViewCell.Model(
            id: delegate.identifier,
            icon: icon,
            name: delegate.metadata?.name ?? delegate.stats.address,
            type: delegate.metadata.map { $0.isOrganization ? .organization : .individual },
            description: delegate.metadata?.shortDescription ?? "",
            delegationsTitle: GovernanceDelegatesOrder.delegations.value(for: selectedLocale),
            delegations: delegations,
            votesTitle: GovernanceDelegatesOrder.delegatedVotes.value(for: selectedLocale),
            votes: totalVotes,
            lastVotesTitle: GovernanceDelegatesOrder.lastVoted(days: lastVotedDays).value(for: selectedLocale),
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
        view?.didReceive(order: selectedOrder)
        view?.didReceive(filter: selectedFilter)
    }

    func selectDelegate(_: GovernanceDelegateTableViewCell.Model) {}

    func closeBanner() {}

    func showAddDelegateInformation() {}

    func showSortOptions() {
        let title = LocalizableResource {
            GovernanceDelegatesOrder.title(for: $0)
        }
        let items = [GovernanceDelegatesOrder.delegations, .delegatedVotes, .lastVoted(days: lastVotedDays)]
        let localizableItems = items.map { item in
            LocalizableResource { [selectedOrder] locale in
                SelectableTitleTableViewCell.Model(
                    title: item.value(for: locale),
                    selected: item == selectedOrder
                )
            }
        }

        let delegate = GoveranaceDelegatePicker(items: items) { [weak self] selectedOrder in
            guard let self = self else { return }
            selectedOrder.map { self.selectedOrder = $0 }
            self.view?.didReceive(order: self.selectedOrder)
            self.shownPickerDelegate = nil
        }

        shownPickerDelegate = delegate
        wireframe.showPicker(
            from: view,
            title: title,
            items: localizableItems,
            selectedIndex: items.firstIndex(of: selectedOrder) ?? 0,
            delegate: delegate
        )
    }

    func showFilters() {
        let title = LocalizableResource {
            GovernanceDelegatesFilter.title(for: $0)
        }
        let items: [GovernanceDelegatesFilter] = [.all, .organizations, .individuals]
        let localizableItems = items.map { item in
            LocalizableResource { [selectedFilter] locale in
                SelectableTitleTableViewCell.Model(
                    title: item.value(for: locale),
                    selected: item == selectedFilter
                )
            }
        }

        let delegate = GoveranaceDelegatePicker(items: items) { [weak self] selectedFilter in
            guard let self = self else { return }
            selectedFilter.map { self.selectedFilter = $0 }
            self.view?.didReceive(filter: self.selectedFilter)
            self.shownPickerDelegate = nil
        }

        shownPickerDelegate = delegate
        wireframe.showPicker(
            from: view,
            title: title,
            items: localizableItems,
            selectedIndex: items.firstIndex(of: selectedFilter) ?? 0,
            delegate: delegate
        )
    }
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
