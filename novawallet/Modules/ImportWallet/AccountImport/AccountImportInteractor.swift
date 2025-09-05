import UIKit
import NovaCrypto
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

final class AccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SelectedWalletSettings
    private(set) var eventCenter: EventCenterProtocol

    private let callStore = CancellableCallStore()

    init(
        metaAccountOperationFactoryProvider: MetaAccountOperationFactoryProviding,
        operationQueue: OperationQueue,
        settings: SelectedWalletSettings,
        secretImportService: SecretImportServiceProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            metaAccountOperationFactoryProvider: metaAccountOperationFactoryProvider,
            operationQueue: operationQueue,
            secretImportService: secretImportService
        )
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        guard !callStore.hasCall else {
            return
        }

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation.extractNoCancellableResultData()
            self?.settings.save(value: accountItem)

            return accountItem
        }

        saveOperation.addDependency(importOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [importOperation]
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.settings.setup()
                self?.eventCenter.notify(with: SelectedWalletSwitched())
                self?.eventCenter.notify(with: NewWalletImported())
                self?.presenter?.didCompleteAccountImport()
            case let .failure(error):
                self?.presenter?.didReceiveAccountImport(error: error)
            }
        }
    }
}
