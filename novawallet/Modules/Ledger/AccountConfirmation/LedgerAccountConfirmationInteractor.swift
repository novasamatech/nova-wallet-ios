import UIKit

enum LedgerAccountConfirmationInteractorError: Error {
    case accountVerificationFailed
}

final class LedgerAccountConfirmationInteractor {
    weak var presenter: LedgerAccountConfirmationInteractorOutputProtocol?

    let chain: ChainModel
    let deviceId: UUID
    let application: LedgerApplication
    let accountsStore: LedgerAccountsStore
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        deviceId: UUID,
        application: LedgerApplication,
        accountsStore: LedgerAccountsStore,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.application = application
        self.deviceId = deviceId
        self.operationQueue = operationQueue
        self.accountsStore = accountsStore
    }

    private func verify(responseAddress: AccountAddress, expectedAddress: AccountAddress, index: UInt32) {
        if
            responseAddress == expectedAddress,
            let accountId = try? responseAddress.toAccountId(using: chain.chainFormat) {
            let chainAccount = LedgerChainAccount(chain: chain, accountId: accountId)
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
        let wrapper = application.getAccountWrapper(for: deviceId, chainId: chain.chainId, index: index)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try wrapper.targetOperation.extractNoCancellableResultData()
                    let account = LedgerAccountAmount(address: response.address, amount: nil)

                    self?.presenter?.didReceiveAccount(result: .success(account), at: index)
                } catch {
                    self?.presenter?.didReceiveAccount(result: .failure(error), at: index)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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

                    self?.verify(responseAddress: response.address, expectedAddress: address, index: index)
                } catch {
                    self?.presenter?.didReceiveConfirmation(result: .failure(error), at: index)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}
