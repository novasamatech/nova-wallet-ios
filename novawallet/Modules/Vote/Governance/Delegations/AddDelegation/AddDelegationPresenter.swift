import Foundation
import SoraFoundation
import RobinHood
import BigInt

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol
    let numberFormatter = NumberFormatter.quantity.localizableResource()
    let chain: ChainModel
    let lastVotedDays: Int
    let logger: LoggerProtocol

    private var delegates: [AccountAddress: GovernanceDelegateLocal] = [:]
    private var selectedFilter = GovernanceDelegatesFilter.all
    private var selectedOrder = GovernanceDelegatesOrder.delegations
    private var shownPickerHandler: ModalPickerViewControllerDelegate?

    init(
        interactor: AddDelegationInteractorInputProtocol,
        wireframe: AddDelegationWireframeProtocol,
        chain: ChainModel,
        lastVotedDays: Int,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let chainAsset = chain.utilityAsset() else {
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

            if let selectedOrder = selectedOrder {
                self.selectedOrder = selectedOrder
                self.view?.didReceive(order: selectedOrder)
            }

            self.shownPickerHandler = nil
        }

        shownPickerHandler = delegate
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

            if let selectedFilter = selectedFilter {
                self.selectedFilter = selectedFilter
                self.view?.didReceive(filter: selectedFilter)
            }

            self.shownPickerHandler = nil
        }

        shownPickerHandler = delegate
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
    func didReceiveDelegates(_ delegates: [GovernanceDelegateLocal]) {
        self.delegates = delegates.reduce(into: [AccountAddress: GovernanceDelegateLocal]()) {
            $0[$1.stats.address] = $1
        }

        updateView()
    }

    func didReceiveError(_ error: AddDelegationInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .blockSubscriptionFailed, .blockTimeFetchFailed:
            interactor.remakeSubscriptions()
        case .delegateListFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshDelegates()
            }
        }
    }
}

extension AddDelegationPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
