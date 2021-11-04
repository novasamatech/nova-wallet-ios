import UIKit
import RobinHood
import BigInt
import SubstrateSdk

final class CrowdloanContributionConfirmInteractor: CrowdloanContributionInteractor, AccountFetching {
    var confirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol? {
        presenter as? CrowdloanContributionConfirmInteractorOutputProtocol
    }

    let signingWrapper: SigningWrapperProtocol
    let bonusService: CrowdloanBonusServiceProtocol?

    init(
        paraId: ParaId,
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        bonusService: CrowdloanBonusServiceProtocol?,
        operationManager: OperationManagerProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.bonusService = bonusService

        super.init(
            paraId: paraId,
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: crowdloanLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            jsonLocalSubscriptionFactory: jsonLocalSubscriptionFactory,
            operationManager: operationManager
        )
    }

    override func setup() {
        super.setup()

        provideRewardDestination()
        do {
            if let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest()) {
                let displayAddress = try accountResponse.toDisplayAddress()
                confirmPresenter?.didReceiveDisplayAddress(result: .success(displayAddress))
            } else {
                confirmPresenter?.didReceiveDisplayAddress(
                    result: .failure(ChainAccountFetchingError.accountNotExists)
                )
            }
        } catch {
            confirmPresenter?.didReceiveDisplayAddress(result: .failure(error))
        }
    }

    private func submitExtrinsicWithSignature(for contribution: BigUInt, signature: MultiSignature?) {
        let call = callFactory.contribute(to: paraId, amount: contribution, signature: signature)

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let nextBuilder = try builder.adding(call: call)
            return try self.bonusService?.applyOnchainBonusForContribution(
                amount: contribution,
                using: nextBuilder
            ) ?? nextBuilder
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.confirmPresenter?.didSubmitContribution(result: result)
            }
        )
    }

    private func submitExtrinsic(for contribution: BigUInt) {
        if let bonusService = bonusService {
            bonusService.provideSignature(
                contribution: contribution
            ) { [weak self] signatureResult in
                switch signatureResult {
                case let .success(signature):
                    self?.submitExtrinsicWithSignature(for: contribution, signature: signature)
                case let .failure(error):
                    self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
                }
            }
        } else {
            submitExtrinsicWithSignature(for: contribution, signature: nil)
        }
    }

    private func provideRewardDestination() {
        guard
            let bonusService = bonusService,
            let address = bonusService.rewardDestinationAddress
        else { return }
        confirmPresenter?.didReceiveRewardDestinationAddress(address)
    }
}

extension CrowdloanContributionConfirmInteractor: CrowdloanContributionConfirmInteractorInputProtocol {
    func submit(contribution: BigUInt) {
        if let bonusService = bonusService {
            bonusService.applyOffchainBonusForContribution(amount: contribution) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.submitExtrinsic(for: contribution)
                    case let .failure(error):
                        self?.confirmPresenter?.didSubmitContribution(result: .failure(error))
                    }
                }
            }
        } else {
            submitExtrinsic(for: contribution)
        }
    }

    func estimateFee(for contribution: BigUInt) {
        estimateFee(for: contribution, bonusService: bonusService)
    }
}
