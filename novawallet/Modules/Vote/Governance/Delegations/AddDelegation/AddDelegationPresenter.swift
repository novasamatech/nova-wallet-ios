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

    func showSortOptions() {
        let title = LocalizableResource {
            DelegatesSortOption.title(for: $0)
        }
        let items = [DelegatesSortOption.delegations, .delegatedVotes, .lastVoted(days: lastVotedDays)]
        let localizableItems = items.map { item in
            LocalizableResource { locale in
                SelectableTitleTableViewCell.Model(
                    title: item.value(for: locale),
                    selected: false
                )
            }
        }

        // move to wireframe
        guard let modal = ModalPickerFactory.createSelectionList(
            title: title,
            items: localizableItems,
            delegate: ModalPickerDelegateWrapper(items: items, closure: { [weak self] in
                self?.view?.update(sortValue: $0)
            })
        ) else {
            return
        }
        view?.controller.present(modal, animated: true)
    }

    func showFilters() {
        let title = LocalizableResource {
            DelegatesShowOption.title(for: $0)
        }
        let items = DelegatesShowOption.allCases
        let localizableItems = items.map { item in
            LocalizableResource { locale in
                SelectableTitleTableViewCell.Model(
                    title: item.value(for: locale),
                    selected: false
                )
            }
        }

        // move to wireframe
        guard let modal = ModalPickerFactory.createSelectionList(
            title: title,
            items: localizableItems,
            delegate: ModalPickerDelegateWrapper(items: items, closure: { [weak self] in
                self?.view?.update(showValue: $0)
            })
        ) else {
            return
        }

        view?.controller.present(modal, animated: true)
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

final class ModalPickerDelegateWrapper<Item>: ModalPickerViewControllerDelegate {
    let closure: (Item) -> Void
    let items: [Item]

    init(items: [Item], closure: @escaping (Item) -> Void) {
        self.items = items
        self.closure = closure
    }

    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        closure(items[index])
    }
}
