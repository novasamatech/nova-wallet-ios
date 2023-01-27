import Foundation
import SoraFoundation
import RobinHood
import BigInt

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let votesDisplayFactory: ReferendumDisplayStringFactoryProtocol
    let addressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let chain: ChainModel
    let lastVotedDays: Int
    let learnDelegateMetadata: URL
    let logger: LoggerProtocol

    private var allDelegates: [AccountAddress: GovernanceDelegateLocal] = [:]
    private var targetDelegates: [GovernanceDelegateLocal] = []
    private var selectedFilter = GovernanceDelegatesFilter.all
    private var selectedOrder = GovernanceDelegatesOrder.delegations
    private var shownPickerHandler: ModalPickerViewControllerDelegate?

    init(
        interactor: AddDelegationInteractorInputProtocol,
        wireframe: AddDelegationWireframeProtocol,
        chain: ChainModel,
        lastVotedDays: Int,
        learnDelegateMetadata: URL,
        addressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        votesDisplayFactory: ReferendumDisplayStringFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.learnDelegateMetadata = learnDelegateMetadata
        self.addressViewModelFactory = addressViewModelFactory
        self.votesDisplayFactory = votesDisplayFactory
        self.quantityFormatter = quantityFormatter
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateTargetDelegates() {
        targetDelegates = allDelegates.values.filter { delegate in
            selectedFilter.matchesDelegate(delegate)
        }.sorted { delegate1, delegate2 in
            selectedOrder.isDescending(delegate1, delegate2: delegate2)
        }
    }

    private func updateView() {
        guard let chainAsset = chain.utilityAsset() else {
            return
        }

        let viewModels = targetDelegates.map { convert(delegate: $0, chainAsset: chainAsset) }
        view?.didReceive(delegateViewModels: viewModels)
    }

    private func convert(
        delegate: GovernanceDelegateLocal,
        chainAsset _: AssetModel
    ) -> GovernanceDelegateTableViewCell.Model {
        let name = delegate.identity?.displayName ?? delegate.metadata?.name

        let addressViewModel = addressViewModelFactory.createViewModel(
            from: delegate.stats.address,
            name: name,
            iconUrl: delegate.metadata?.image
        )

        let numberFormatter = quantityFormatter.value(for: selectedLocale)
        let delegations = numberFormatter.string(from: NSNumber(value: delegate.stats.delegationsCount))

        let totalVotes = votesDisplayFactory.createVotesValue(
            from: delegate.stats.delegatedVotes,
            chain: chain,
            locale: selectedLocale
        )

        let lastVotes = numberFormatter.string(from: NSNumber(value: delegate.stats.recentVotes))

        return GovernanceDelegateTableViewCell.Model(
            addressViewModel: addressViewModel,
            type: delegate.metadata.map { $0.isOrganization ? .organization : .individual },
            description: delegate.metadata?.shortDescription,
            delegationsTitle: GovernanceDelegatesOrder.delegations.value(for: selectedLocale),
            delegations: delegations,
            votesTitle: GovernanceDelegatesOrder.delegatedVotes.value(for: selectedLocale),
            votes: totalVotes,
            lastVotesTitle: GovernanceDelegatesOrder.lastVoted(days: lastVotedDays).value(for: selectedLocale),
            lastVotes: lastVotes
        )
    }
}

extension AddDelegationPresenter: AddDelegationPresenterProtocol {
    func setup() {
        interactor.setup()
        view?.didReceive(order: selectedOrder)
        view?.didReceive(filter: selectedFilter)
    }

    func selectDelegate(_ viewModel: GovernanceDelegateTableViewCell.Model) {
        guard let delegate = allDelegates[viewModel.addressViewModel.address] else {
            return
        }

        wireframe.showInfo(from: view, delegate: delegate)
    }

    func closeBanner() {
        view?.didChangeBannerState(isHidden: true, animated: true)
        interactor.saveCloseBanner()
    }

    func showAddDelegateInformation() {
        if let view = view {
            wireframe.showWeb(url: learnDelegateMetadata, from: view, style: .automatic)
        }
    }

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

                self.updateTargetDelegates()
                self.updateView()
            }

            self.shownPickerHandler = nil

            self.view?.didCompleteListConfiguration()
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

                self.updateTargetDelegates()
                self.updateView()
            }

            self.shownPickerHandler = nil

            self.view?.didCompleteListConfiguration()
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
    func didReceiveShouldDisplayBanner(_ isHidden: Bool) {
        view?.didChangeBannerState(isHidden: isHidden, animated: false)
    }

    func didReceiveDelegates(_ delegates: [GovernanceDelegateLocal]) {
        allDelegates = delegates.reduce(into: [AccountAddress: GovernanceDelegateLocal]()) {
            $0[$1.stats.address] = $1
        }

        updateTargetDelegates()
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
