import UIKit
import BigInt
import SubstrateSdk

final class NominationPoolBondMoreConfirmInteractor: NominationPoolBondMoreBaseInteractor {
    weak var presenter: NominationPoolBondMoreConfirmInteractorOutputProtocol? {
        basePresenter as? NominationPoolBondMoreConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol
    let extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        signingWrapper: SigningWrapperProtocol
    ) {
        self.signingWrapper = signingWrapper

        let extrinsicService = extrinsicServiceFactory.createService(
            account: selectedAccount.chainAccount,
            chain: chainAsset.chain
        )

        extrinsicMonitorFactory = extrinsicServiceFactory.createExtrinsicSubmissionMonitor(
            with: extrinsicService
        )

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            callFactory: callFactory,
            extrinsicService: extrinsicService,
            npoolsOperationFactory: npoolsOperationFactory,
            npoolsLocalSubscriptionFactory: npoolsLocalSubscriptionFactory,
            assetStorageInfoFactory: assetStorageInfoFactory,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}

extension NominationPoolBondMoreConfirmInteractor: NominationPoolBondMoreConfirmInteractorInputProtocol {
    func submit(amount: BigUInt, needsMigration: Bool) {
        let wrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: createExtrinsicClosure(
                for: amount,
                accountId: accountId,
                needsMigration: needsMigration
            ),
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result.mapToExtrinsicSubmittedResult())
        }
    }
}
