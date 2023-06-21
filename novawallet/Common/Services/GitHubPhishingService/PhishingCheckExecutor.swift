import Foundation
import RobinHood
import CoreData
import SoraFoundation

class PhishingCheckExecutor {
    private let storage: AnyDataProviderRepository<PhishingItem>
    private let nextActionBlock: () -> Void
    private let cancelActionBlock: () -> Void
    private let locale: Locale
    private let publicKey: String
    private let displayName: String

    init(
        storage: AnyDataProviderRepository<PhishingItem>,
        nextAction nextActionBlock: @escaping () -> Void,
        cancelAction cancelActionBlock: @escaping () -> Void,
        locale: Locale,
        publicKey: String,
        walletAddress displayName: String
    ) {
        self.storage = storage
        self.nextActionBlock = nextActionBlock
        self.cancelActionBlock = cancelActionBlock
        self.locale = locale
        self.publicKey = publicKey
        self.displayName = displayName
    }

    func execute() throws {
        let fetchOperation = storage.fetchOperation(
            by: publicKey,
            options: RepositoryFetchOptions()
        )

        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = try? fetchOperation.extractResultData() {
                    guard result != nil else {
                        self.nextActionBlock()
                        return
                    }

                    let alertController = UIAlertController.phishingWarningAlert(
                        onConfirm: self.nextActionBlock,
                        onCancel: self.cancelActionBlock,
                        locale: self.locale,
                        displayName: self.displayName
                    )

                    // TODO: Return phishing
                }
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .transient)
    }
}
