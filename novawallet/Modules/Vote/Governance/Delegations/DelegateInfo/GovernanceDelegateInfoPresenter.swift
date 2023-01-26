import Foundation
import SoraFoundation

final class GovernanceDelegateInfoPresenter {
    weak var view: GovernanceDelegateInfoViewProtocol?
    let wireframe: GovernanceDelegateInfoWireframeProtocol
    let interactor: GovernanceDelegateInfoInteractorInputProtocol
    let logger: LoggerProtocol

    let initStats: GovernanceDelegateStats?

    private var details: GovernanceDelegateDetails?
    private var metadata: GovernanceDelegateMetadataRemote?
    private var identity: AccountIdentity?

    init(
        interactor: GovernanceDelegateInfoInteractorInputProtocol,
        wireframe: GovernanceDelegateInfoWireframeProtocol,
        initDelegate: GovernanceDelegateLocal?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        initStats = initDelegate?.stats
        metadata = initDelegate?.metadata
        identity = initDelegate?.identity
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentFullDescription() {}

    func presentDelegations() {}

    func presentRecentVotes() {}

    func presentAllVotes() {}

    func presentIdentityItem(_: ValidatorInfoViewModel.IdentityItemValue) {}

    func presentAccountOptions() {}

    func addDelegation() {}
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoInteractorOutputProtocol {
    func didReceiveDetails(_ details: GovernanceDelegateDetails?) {
        self.details = details
    }

    func didReceiveMetadata(_ metadata: GovernanceDelegateMetadataRemote?) {
        self.metadata = metadata
    }

    func didReceiveIdentity(_ identity: AccountIdentity?) {
        self.identity = identity
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
        if let view = view, view.isSetup {}
    }
}
