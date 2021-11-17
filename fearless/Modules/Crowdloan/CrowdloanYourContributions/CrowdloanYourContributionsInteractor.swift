import UIKit
import RobinHood

final class CrowdloanYourContributionsInteractor {
    weak var presenter: CrowdloanYourContributionsInteractorOutputProtocol!

    let chain: ChainModel
    let selectedMetaAccount: MetaAccountModel
    let operationManager: OperationManagerProtocol
    let externalContrubutionSources: [ExternalContributionSourceProtocol]

    init(
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        externalContrubutionSources: [ExternalContributionSourceProtocol]
    ) {
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
        self.operationManager = operationManager
        self.externalContrubutionSources = externalContrubutionSources
    }

    private func fetchExternalContributions() {
        guard
            let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId
        else {
            presenter.didReceiveExternalContributions(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let contributionsOperation: BaseOperation<[[ExternalContribution]]> =
            OperationCombiningService(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return []
                }

                return self.externalContrubutionSources
                    .filter { $0.supports(chain: self.chain) }
                    .map { source -> CompoundOperationWrapper<[ExternalContribution]> in
                        CompoundOperationWrapper<[ExternalContribution]>(
                            targetOperation: source.getContributions(accountId: accountId, chain: self.chain)
                        )
                    }
            }.longrunOperation()

        contributionsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let contributions = try contributionsOperation.extractNoCancellableResultData().flatMap { $0 }
                    self?.presenter.didReceiveExternalContributions(result: .success(contributions))
                } catch {
                    self?.presenter.didReceiveExternalContributions(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [contributionsOperation], in: .transient)
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanYourContributionsInteractorInputProtocol {
    func setup() {
        fetchExternalContributions()
    }
}
