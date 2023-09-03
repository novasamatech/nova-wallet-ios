import UIKit
import BigInt

final class NominationPoolBondMoreConfirmInteractor: NominationPoolBondMoreBaseInteractor {
    weak var presenter: NominationPoolBondMoreConfirmInteractorOutputProtocol? {
        basePresenter as? NominationPoolBondMoreConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol

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
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        signingWrapper: SigningWrapperProtocol
    ) {
        self.signingWrapper = signingWrapper
        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            callFactory: callFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            npoolsOperationFactory: npoolsOperationFactory,
            npoolsLocalSubscriptionFactory: npoolsLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            assetStorageInfoFactory: assetStorageInfoFactory,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}

extension NominationPoolBondMoreConfirmInteractor: NominationPoolBondMoreConfirmInteractorInputProtocol {
    func submit(amount: BigUInt) {
        extrinsicService.submit(
            createExtrinsicClosure(for: amount),
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result)
        }
    }
}
