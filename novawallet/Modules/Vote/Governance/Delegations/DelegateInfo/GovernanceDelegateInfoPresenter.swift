import Foundation
import SoraFoundation

final class GovernanceDelegateInfoPresenter {
    weak var view: GovernanceDelegateInfoViewProtocol?
    let wireframe: GovernanceDelegateInfoWireframeProtocol
    let interactor: GovernanceDelegateInfoInteractorInputProtocol
    let logger: LoggerProtocol

    let infoViewModelFactory: GovernanceDelegateInfoViewModelFactoryProtocol
    let identityViewModelFactory: IdentityViewModelFactoryProtocol
    let initStats: GovernanceDelegateStats?
    let chain: ChainModel

    private var details: GovernanceDelegateDetails?
    private var metadata: GovernanceDelegateMetadataRemote?
    private var identity: AccountIdentity?
    private var delegateProfileViewModel: GovernanceDelegateProfileView.Model?

    var delegateAddress: AccountAddress? {
        details?.stats.address ?? initStats?.address
    }

    init(
        interactor: GovernanceDelegateInfoInteractorInputProtocol,
        wireframe: GovernanceDelegateInfoWireframeProtocol,
        chain: ChainModel,
        initDelegate: GovernanceDelegateLocal?,
        infoViewModelFactory: GovernanceDelegateInfoViewModelFactoryProtocol,
        identityViewModelFactory: IdentityViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.infoViewModelFactory = infoViewModelFactory
        self.identityViewModelFactory = identityViewModelFactory
        initStats = initDelegate?.stats
        metadata = initDelegate?.metadata
        identity = initDelegate?.identity
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideDelegateViewModel() {
        guard let delegateAddress = delegateAddress else {
            return
        }

        let viewModel = infoViewModelFactory.createDelegateViewModel(
            from: delegateAddress,
            metadata: metadata,
            identity: identity
        )

        delegateProfileViewModel = viewModel.profileViewModel
        view?.didReceiveDelegate(viewModel: viewModel)
    }

    private func provideStatsViewModel() {
        let optViewModel: GovernanceDelegateInfoViewModel.Stats?

        if let details = details {
            optViewModel = infoViewModelFactory.createStatsViewModel(
                from: details,
                chain: chain,
                locale: selectedLocale
            )
        } else if let stats = initStats {
            optViewModel = infoViewModelFactory.createStatsViewModel(
                using: stats,
                chain: chain,
                locale: selectedLocale
            )
        } else {
            optViewModel = nil
        }

        guard let viewModel = optViewModel else {
            return
        }

        view?.didReceiveStats(viewModel: viewModel)
    }

    private func provideYourDelegations() {
        // TODO: #860pmdth8
        view?.didReceiveYourDelegation(viewModel: nil)
    }

    private func provideIdentity() {
        if let identity = identity {
            let viewModel = identityViewModelFactory.createIdentityViewModel(
                from: identity,
                locale: selectedLocale
            )

            view?.didReceiveIdentity(items: viewModel)
        } else {
            view?.didReceiveIdentity(items: nil)
        }
    }

    private func provideViewModels() {
        provideDelegateViewModel()
        provideStatsViewModel()
        provideYourDelegations()
        provideIdentity()
    }
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoPresenterProtocol {
    func setup() {
        provideViewModels()

        interactor.setup()
    }

    func presentFullDescription() {
        guard let delegateProfileViewModel = delegateProfileViewModel,
              let longDescription = metadata?.longDescription else {
            return
        }

        wireframe.showFullDescription(
            from: view,
            name: delegateProfileViewModel.name,
            longDescription: longDescription
        )
    }

    func presentDelegations() {
        guard let address = delegateAddress else {
            return
        }

        wireframe.showDelegations(from: view, delegateAddress: address)
    }

    func presentRecentVotes() {
        guard let address = delegateAddress else {
            return
        }

        wireframe.showRecentVotes(from: view, delegateAddress: address)
    }

    func presentAllVotes() {
        guard let address = delegateAddress else {
            return
        }

        wireframe.showAllVotes(from: view, delegateAddress: address)
    }

    func presentIdentityItem(_ item: ValidatorInfoViewModel.IdentityItemValue) {
        guard case let .link(value, tag) = item, let view = view else {
            return
        }

        wireframe.presentIdentityItem(
            from: view,
            tag: tag,
            value: value,
            locale: selectedLocale
        )
    }

    func presentAccountOptions() {
        guard let address = delegateAddress, let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func addDelegation() {
        guard let delegate = try? delegateAddress?.toAccountId() else {
            return
        }

        wireframe.showAddDelegation(from: view, delegate: delegate)
    }
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoInteractorOutputProtocol {
    func didReceiveDetails(_ details: GovernanceDelegateDetails?) {
        if self.details != details {
            self.details = details

            provideDelegateViewModel()
            provideStatsViewModel()
        }
    }

    func didReceiveMetadata(_ metadata: GovernanceDelegateMetadataRemote?) {
        if metadata != self.metadata {
            self.metadata = metadata

            provideDelegateViewModel()
        }
    }

    func didReceiveIdentity(_ identity: AccountIdentity?) {
        if self.identity != identity {
            self.identity = identity

            provideDelegateViewModel()
            provideIdentity()
        }
    }

    func didReceiveError(_ error: GovernanceDelegateInfoError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .detailsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshDetails()
            }
        case .metadataSubscriptionFailed, .blockSubscriptionFailed, .blockTimeFetchFailed:
            interactor.remakeSubscriptions()
        case .identityFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshIdentity()
            }
        }
    }
}

extension GovernanceDelegateInfoPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
