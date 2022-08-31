import UIKit
import SubstrateSdk
import RobinHood

final class LedgerWalletAccountConfirmationInteractor: LedgerBaseAccountConfirmationInteractor,
    LedgerAccountConfirmationInteractorInputProtocol {
    let accountsStore: LedgerAccountsStore

    init(
        chain: ChainModel,
        deviceId: UUID,
        application: LedgerApplication,
        accountsStore: LedgerAccountsStore,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountsStore = accountsStore

        super.init(
            chain: chain,
            deviceId: deviceId,
            application: application,
            requestFactory: requestFactory,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue
        )
    }

    override func addAccount(
        for info: LedgerChainAccount.Info,
        chain: ChainModel,
        derivationPath: Data,
        index: UInt32
    ) {
        accountsStore.add(chain: chain, info: info, derivationPath: derivationPath)

        presenter?.didReceiveConfirmation(result: .success(info.accountId), at: index)
    }
}
