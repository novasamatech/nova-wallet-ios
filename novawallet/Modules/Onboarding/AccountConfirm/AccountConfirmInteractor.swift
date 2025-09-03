import UIKit
import Keystore_iOS
import NovaCrypto
import Operation_iOS

class AccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SelectedWalletSettings
    
    private let callStore = CancellableCallStore()

    let eventCenter: EventCenterProtocol

    init(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            request: request,
            mnemonic: mnemonic,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationQueue: operationQueue
        )
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        guard !callStore.hasCall else {
            return
        }

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
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
                self?.eventCenter.notify(with: NewWalletCreated())
                self?.presenter?.didCompleteConfirmation()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }
}
