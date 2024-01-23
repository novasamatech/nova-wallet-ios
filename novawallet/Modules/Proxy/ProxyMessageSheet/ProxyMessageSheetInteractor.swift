import Foundation
import RobinHood

final class ProxyMessageSheetInteractor {
    let repository: AnyDataProviderRepository<ProxiedSettings>
    let operationQueue: OperationQueue
    let metaId: MetaAccountModel.Id
    let logger: LoggerProtocol

    init(
        metaId: MetaAccountModel.Id,
        repository: AnyDataProviderRepository<ProxiedSettings>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.metaId = metaId
        self.repository = repository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func performSave(for metaId: MetaAccountModel.Id, completion: @escaping () -> Void) {
        let saveOperation = repository.saveOperation({
            let model = ProxiedSettings(identifier: metaId, confirmsOperation: false)
            return [model]
        }, {
            []
        })

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Unexpected error: \(error)")
            }

            completion()
        }
    }
}

extension ProxyMessageSheetInteractor: ProxyMessageSheetInteractorInputProtocol {
    func saveNoConfirmation(for completion: @escaping () -> Void) {
        performSave(for: metaId, completion: completion)
    }
}
