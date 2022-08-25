import UIKit
import SubstrateSdk
import RobinHood

enum LedgerAccountConfirmationInteractorError: Error {
    case accountVerificationFailed
}

final class LedgerAccountConfirmationInteractor {
    weak var presenter: LedgerAccountConfirmationInteractorOutputProtocol?

    let chain: ChainModel
    let deviceId: UUID
    let application: LedgerApplication
    let accountsStore: LedgerAccountsStore
    let requestFactory: StorageRequestFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

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
        self.chain = chain
        self.application = application
        self.deviceId = deviceId
        self.operationQueue = operationQueue
        self.requestFactory = requestFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.accountsStore = accountsStore
    }

    private func verify(response: LedgerAccount, expectedAddress: AccountAddress, index: UInt32) {
        if
            response.address == expectedAddress,
            let accountId = try? response.address.toAccountId(using: chain.chainFormat) {
            let info = LedgerChainAccount.Info(
                accountId: accountId,
                publicKey: response.publicKey,
                cryptoType: LedgerApplication.defaultCryptoScheme.walletCryptoType
            )

            let chainAccount = LedgerChainAccount(chain: chain, info: info)
            accountsStore.add(chainAccount: chainAccount)

            presenter?.didReceiveConfirmation(result: .success(accountId), at: index)
        } else {
            presenter?.didReceiveConfirmation(
                result: .failure(LedgerAccountConfirmationInteractorError.accountVerificationFailed),
                at: index
            )
        }
    }
}

extension LedgerAccountConfirmationInteractor: LedgerAccountConfirmationInteractorInputProtocol {
    func fetchAccount(for index: UInt32) {
        let ledgerWrapper = application.getAccountWrapper(for: deviceId, chainId: chain.chainId, index: index)

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [Data] = {
            let account = try ledgerWrapper.targetOperation.extractNoCancellableResultData()
            let accountId = try account.address.toAccountId()
            return [accountId]
        }

        let balanceWrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: keyParams,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: .account
        )

        balanceWrapper.addDependency(wrapper: ledgerWrapper)
        balanceWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<LedgerAccountAmount> {
            let ledgerResponse = try ledgerWrapper.targetOperation.extractNoCancellableResultData()
            let balanceResponse = try balanceWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return LedgerAccountAmount(address: ledgerResponse.address, amount: balanceResponse?.data.total)
        }

        mappingOperation.addDependency(balanceWrapper.targetOperation)
        mappingOperation.addDependency(ledgerWrapper.targetOperation)

        mappingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let account = try mappingOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveAccount(result: .success(account), at: index)
                } catch {
                    self?.presenter?.didReceiveAccount(result: .failure(error), at: index)
                }
            }
        }

        let operations = ledgerWrapper.allOperations + [codingFactoryOperation] + balanceWrapper.allOperations
            + [mappingOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    func confirm(address: AccountAddress, at index: UInt32) {
        let wrapper = application.getAccountWrapper(
            for: deviceId,
            chainId: chain.chainId,
            index: index,
            displayVerificationDialog: true
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.verify(response: response, expectedAddress: address, index: index)
                } catch {
                    self?.presenter?.didReceiveConfirmation(result: .failure(error), at: index)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}
