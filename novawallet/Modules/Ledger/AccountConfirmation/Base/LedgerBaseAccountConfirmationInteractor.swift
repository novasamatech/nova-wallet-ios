import UIKit
import SubstrateSdk
import Operation_iOS

enum LedgerAccountConfirmationInteractorError: Error {
    case accountVerificationFailed
}

class LedgerBaseAccountConfirmationInteractor {
    weak var presenter: LedgerAccountConfirmationInteractorOutputProtocol?

    let chain: ChainModel
    let deviceId: UUID
    let application: LedgerAccountRetrievable
    let requestFactory: StorageRequestFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        deviceId: UUID,
        application: LedgerAccountRetrievable,
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
    }

    func addAccount(for _: LedgerChainAccount.Info, chain _: ChainModel, derivationPath _: Data, index _: UInt32) {
        assertionFailure("Child interactor must override this method")
    }

    private func verify(response: LedgerSubstrateAccountResponse, expectedAddress: AccountAddress, index: UInt32) {
        let responseAccount = response.account

        if
            responseAccount.address == expectedAddress,
            let accountId = try? responseAccount.address.toAccountId(using: chain.chainFormat) {
            let info = LedgerChainAccount.Info(
                accountId: accountId,
                publicKey: responseAccount.publicKey,
                cryptoType: LedgerConstants.defaultSubstrateCryptoScheme.walletCryptoType
            )

            addAccount(for: info, chain: chain, derivationPath: response.derivationPath, index: index)
        } else {
            presenter?.didReceiveConfirmation(
                result: .failure(LedgerAccountConfirmationInteractorError.accountVerificationFailed),
                at: index
            )
        }
    }

    func fetchAccount(for index: UInt32) {
        let ledgerWrapper = application.getAccountWrapper(for: deviceId, chainId: chain.chainId, index: index)

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [Data] = {
            let account = try ledgerWrapper.targetOperation.extractNoCancellableResultData().account
            let accountId = try account.address.toAccountId()
            return [accountId]
        }

        let balanceWrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: keyParams,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: SystemPallet.accountPath
        )

        balanceWrapper.addDependency(wrapper: ledgerWrapper)
        balanceWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<LedgerAccountAmount> {
            let ledgerResponse = try ledgerWrapper.targetOperation.extractNoCancellableResultData()
            let balanceResponse = try balanceWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return LedgerAccountAmount(address: ledgerResponse.account.address, amount: balanceResponse?.data.total)
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

    func cancelRequest() {
        application.connectionManager.cancelRequest(for: deviceId)
    }
}
