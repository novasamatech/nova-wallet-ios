import UIKit
import BigInt
import RobinHood

final class TransferConfirmInteractor: TransferInteractor {
    let signingWrapper: SigningWrapperProtocol

    var submitionPresenter: TransferConfirmInteractorOutputProtocol? {
        presenter as? TransferConfirmInteractorOutputProtocol
    }

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade _: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            walletRemoteWrapper: walletRemoteWrapper,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: operationQueue
        )
    }
}

extension TransferConfirmInteractor: TransferConfirmInteractorInputProtocol {
    func submit(amount: BigUInt, recepient: AccountAddress) {
        do {
            let accountId = try recepient.toAccountId(using: chain.chainFormat)

            let extrinsicClosure: ExtrinsicBuilderClosure = { [weak self] builder in
                guard let strongSelf = self else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                return try strongSelf.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: accountId
                )
            }

            extrinsicService.submit(
                extrinsicClosure,
                signer: signingWrapper,
                runningIn: .main,
                completion: { [weak self] result in
                    switch result {
                    case .success:
                        self?.submitionPresenter?.didCompleteSubmition()
                    case let .failure(error):
                        self?.presenter?.didReceiveSetup(error: error)
                    }
                }
            )
        } catch {
            presenter?.didReceiveSetup(error: error)
        }
    }
}
