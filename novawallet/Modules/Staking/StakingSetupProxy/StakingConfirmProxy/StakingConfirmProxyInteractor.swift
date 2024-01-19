import UIKit

final class StakingConfirmProxyInteractor: StakingProxyBaseInteractor {
    weak var presenter: StakingConfirmProxyInteractorOutputProtocol? {
        basePresenter as? StakingConfirmProxyInteractorOutputProtocol
    }

    let proxyAccount: AccountAddress
    let signingWrapper: SigningWrapperProtocol
    let operation: StakingProxyConfirmOperation

    init(
        proxyAccount: AccountAddress,
        signingWrapper: SigningWrapperProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        sharedState: RelaychainStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        selectedAccount: ChainAccountResponse,
        currencyManager: CurrencyManagerProtocol,
        operation: StakingProxyConfirmOperation,
        operationQueue: OperationQueue
    ) {
        self.proxyAccount = proxyAccount
        self.signingWrapper = signingWrapper
        self.operation = operation

        super.init(
            runtimeService: runtimeService,
            sharedState: sharedState,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            callFactory: callFactory,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            selectedAccount: selectedAccount,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

extension StakingConfirmProxyInteractor: StakingConfirmProxyInteractorInputProtocol {
    func submit() {
        guard let proxyAccountId = try? proxyAccount.toAccountId(
            using: chainAsset.chain.chainFormat
        ) else {
            presenter?.didReceive(error: .submit(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            operation.builderClosure(
                callFactory: callFactory,
                accountId: proxyAccountId
            ),
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                switch result {
                case .success:
                    self?.presenter?.didSubmit()
                case let .failure(error):
                    self?.presenter?.didReceive(error: .submit(error))
                }
            }
        )
    }
}
