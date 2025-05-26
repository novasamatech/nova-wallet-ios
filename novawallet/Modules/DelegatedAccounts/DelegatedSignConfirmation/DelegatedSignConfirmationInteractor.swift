import Foundation
import Operation_iOS

final class DelegatedSignConfirmationInteractor {
    weak var presenter: DelegatedSignConfirmationInteractorOutputProtocol?

    let delegatedAccountId: MetaAccountModel.Id
    let repository: AnyDataProviderRepository<ProxiedSettings>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        delegatedAccountId: MetaAccountModel.Id,
        repository: AnyDataProviderRepository<ProxiedSettings>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.delegatedAccountId = delegatedAccountId
        self.repository = repository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func provideSettings(for metaId: MetaAccountModel.Id) {
        let fetchOperation = repository.fetchOperation(
            by: { metaId },
            options: .init(includesProperties: true, includesSubentities: true)
        )

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(settings):
                self?.presenter?.didReceive(needsConfirmation: settings?.confirmsOperation ?? true)
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
            }
        }
    }
}

extension DelegatedSignConfirmationInteractor: DelegatedSignConfirmationInteractorInputProtocol {
    func setup() {
        provideSettings(for: delegatedAccountId)
    }
}
