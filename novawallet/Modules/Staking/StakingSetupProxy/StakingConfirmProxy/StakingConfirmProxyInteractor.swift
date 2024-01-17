import UIKit

final class StakingConfirmProxyInteractor: StakingProxyBaseInteractor {
    weak var presenter: StakingConfirmProxyInteractorOutputProtocol? {
        basePresenter as? StakingConfirmProxyInteractorOutputProtocol
    }

    let proxyAccount: AccountAddress
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    private var signingWrapper: SigningWrapperProtocol?

    init(
        proxyAccount: AccountAddress,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        sharedState: RelaychainStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.proxyAccount = proxyAccount
        self.signingWrapperFactory = signingWrapperFactory

        super.init(
            runtimeService: runtimeService,
            sharedState: sharedState,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            callFactory: callFactory,
            feeProxy: feeProxy,
            extrinsicServiceFactory: extrinsicServiceFactory,
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    override func handleStashItemChainAccountResponse(
        _ response: MetaChainAccountResponse?
    ) {
        super.handleStashItemChainAccountResponse(response)

        if let response = response {
            signingWrapper = signingWrapperFactory.createSigningWrapper(
                for: response.metaId,
                accountResponse: response.chainAccount
            )
        } else {
            signingWrapper = nil
        }
    }
}

extension StakingConfirmProxyInteractor: StakingConfirmProxyInteractorInputProtocol {
    func submit() {
        guard let extrinsicService = extrinsicService,
              let signingWrapper = signingWrapper,
              let proxyAccountId = try? proxyAccount.toAccountId(
                  using: chainAsset.chain.chainFormat
              ) else {
            presenter?.didReceive(error: .submit(CommonError.undefined))
            return
        }

        let call = callFactory.addProxy(
            accountId: proxyAccountId,
            type: .staking
        )

        extrinsicService.submit(
            { builder in
                try builder.adding(call: call)
            },
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
