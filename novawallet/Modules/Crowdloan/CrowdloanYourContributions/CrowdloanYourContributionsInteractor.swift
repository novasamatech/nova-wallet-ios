import UIKit
import RobinHood

final class CrowdloanYourContributionsInteractor {
    weak var presenter: CrowdloanYourContributionsInteractorOutputProtocol!

    let chain: ChainModel
    let selectedMetaAccount: MetaAccountModel
    let operationManager: OperationManagerProtocol
    let crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol

    private var externalContributionsProvider: AnySingleValueProvider<[ExternalContribution]>?

    init(
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol
    ) {
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
        self.operationManager = operationManager
        self.crowdloanOffchainProviderFactory = crowdloanOffchainProviderFactory
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanYourContributionsInteractorInputProtocol {
    func setup() {
        if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
            externalContributionsProvider = subscribeToExternalContributionsProvider(
                for: accountId,
                chain: chain
            )
        } else {
            presenter.didReceiveExternalContributions(result: .failure(ChainAccountFetchingError.accountNotExists))
        }
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanOffchainSubscriber, CrowdloanOffchainSubscriptionHandler {
    func handleExternalContributions(
        result: Result<[ExternalContribution]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(maybeContributions):
            presenter.didReceiveExternalContributions(result: .success(maybeContributions ?? []))
        case let .failure(error):
            presenter.didReceiveExternalContributions(result: .failure(error))
        }
    }
}
