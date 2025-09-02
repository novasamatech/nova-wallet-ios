import Foundation
import Foundation_iOS
import Operation_iOS
import BigInt

final class AddDelegationPresenter {
    weak var view: AddDelegationViewProtocol?
    let wireframe: AddDelegationWireframeProtocol
    let interactor: AddDelegationInteractorInputProtocol
    let viewModelFactory: GovernanceDelegateViewModelFactoryProtocol
    let yourDelegationsViewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol
    let chain: ChainModel
    let learnDelegateMetadata: URL
    let lastVotedDays: Int
    let logger: LoggerProtocol
    let yourDelegations: [AccountAddress: GovernanceYourDelegationGroup]

    private var allDelegates: [AccountAddress: GovernanceDelegateLocal]?
    private var targetDelegates: [GovernanceDelegateLocal] = []
    private var metadata: [GovernanceDelegateMetadataRemote]?
    private var selectedFilter = GovernanceDelegatesFilter.all
    private var selectedOrder = GovernanceDelegatesOrder.delegations
    private var shownPickerHandler: ModalPickerViewControllerDelegate?

    init(
        interactor: AddDelegationInteractorInputProtocol,
        wireframe: AddDelegationWireframeProtocol,
        chain: ChainModel,
        lastVotedDays: Int,
        viewModelFactory: GovernanceDelegateViewModelFactoryProtocol,
        yourDelegationsViewModelFactory: GovernanceYourDelegationsViewModelFactoryProtocol,
        learnDelegateMetadata: URL,
        yourDelegations: [GovernanceYourDelegationGroup],
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.viewModelFactory = viewModelFactory
        self.learnDelegateMetadata = learnDelegateMetadata
        self.logger = logger
        self.yourDelegationsViewModelFactory = yourDelegationsViewModelFactory
        self.yourDelegations = yourDelegations.reduce(into: [AccountAddress: GovernanceYourDelegationGroup]()) {
            $0[$1.delegateModel.stats.address] = $1
        }
        self.localizationManager = localizationManager
    }

    private func updateTargetDelegates() {
        guard let allDelegates = allDelegates else {
            return
        }

        let metadataDelegates = (metadata ?? [])
            .filter { allDelegates[$0.address] == nil }
            .map {
                GovernanceDelegateLocal(
                    stats: .init(address: $0.address),
                    metadata: $0,
                    identity: nil
                )
            }

        targetDelegates = (allDelegates.values + metadataDelegates).filter { delegate in
            selectedFilter.matchesDelegate(delegate)
        }.sortedByOrder(selectedOrder)
    }

    private func updateView() {
        let viewModels = targetDelegates.compactMap {
            if let yourDelegate = yourDelegations[$0.stats.address] {
                return createYourDelegateViewModel(delegate: yourDelegate)
            } else {
                return createDelegateViewModel(delegate: $0)
            }
        }

        view?.didReceive(delegateViewModels: viewModels)
    }

    private func createYourDelegateViewModel(delegate: GovernanceYourDelegationGroup) -> AddDelegationViewModel? {
        yourDelegationsViewModelFactory.createYourDelegateViewModel(
            from: delegate,
            chain: chain,
            locale: selectedLocale
        ).map {
            .yourDelegate($0)
        }
    }

    private func createDelegateViewModel(delegate: GovernanceDelegateLocal) -> AddDelegationViewModel? {
        let viewModel = viewModelFactory.createAnyDelegateViewModel(
            from: delegate,
            chain: chain,
            locale: selectedLocale
        )

        return .delegate(viewModel)
    }
}

extension AddDelegationPresenter: AddDelegationPresenterProtocol {
    func setup() {
        interactor.setup()
        view?.didReceive(order: selectedOrder)
        view?.didReceive(filter: selectedFilter)
    }

    func selectDelegate(address: AccountAddress) {
        guard let delegate = targetDelegates.first(where: { $0.stats.address == address }) else {
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

    func showSearch() {
        wireframe.showSearch(
            from: view,
            initDelegates: allDelegates ?? [:],
            initDelegations: yourDelegations
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

    func didReceiveMetadata(_ metadata: [GovernanceDelegateMetadataRemote]?) {
        self.metadata = metadata

        updateTargetDelegates()
        updateView()
    }

    func didReceiveError(_ error: AddDelegationInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .blockSubscriptionFailed, .metadataSubscriptionFailed:
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
