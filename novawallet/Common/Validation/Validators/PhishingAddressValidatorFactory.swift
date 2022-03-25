import Foundation
import RobinHood

protocol PhishingAddressValidatorFactoryProtocol {
    func notPhishing(address: AccountAddress?, locale: Locale) -> DataValidating
}

final class PhishingAddressValidatorFactory {
    let repository: AnyDataProviderRepository<PhishingItem>
    let operationQueue: OperationQueue

    weak var view: ControllerBackedProtocol?
    let presentable: PhishingErrorPresentable

    init(
        repository: AnyDataProviderRepository<PhishingItem>,
        presentable: PhishingErrorPresentable,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.presentable = presentable
        self.operationQueue = operationQueue
    }
}

extension PhishingAddressValidatorFactory: PhishingAddressValidatorFactoryProtocol {
    func notPhishing(address: AccountAddress?, locale: Locale) -> DataValidating {
        AsyncWarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentPhishingWarning(
                address: address,
                view: view,
                action: {
                    delegate.didCompleteAsyncHandling()
                },
                locale: locale
            )
        }, preservesCondition: { [weak self] completionClosure in
            guard let strongSelf = self, let accountIdHex = try? address?.toAccountId().toHex() else {
                completionClosure(false)
                return
            }

            let operation = strongSelf.repository.fetchOperation(
                by: accountIdHex,
                options: RepositoryFetchOptions()
            )

            operation.completionBlock = {
                DispatchQueue.main.async {
                    do {
                        let recordExists = (try operation.extractNoCancellableResultData()) != nil
                        completionClosure(!recordExists)
                    } catch {
                        completionClosure(false)
                    }
                }
            }

            strongSelf.operationQueue.addOperation(operation)
        })
    }
}
