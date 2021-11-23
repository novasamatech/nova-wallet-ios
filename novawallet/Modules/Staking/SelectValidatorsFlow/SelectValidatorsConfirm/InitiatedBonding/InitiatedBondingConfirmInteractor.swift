import Foundation
import RobinHood
import SoraKeystore

final class InitiatedBondingConfirmInteractor: SelectValidatorsConfirmInteractorBase {
    let nomination: PreparedNomination<InitiatedBonding>
    let selectedAccount: DisplayAddress

    init(
        selectedAccount: DisplayAddress,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        nomination: PreparedNomination<InitiatedBonding>
    ) {
        self.nomination = nomination
        self.selectedAccount = selectedAccount

        super.init(
            balanceAccountAddress: selectedAccount.address,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: durationOperationFactory,
            operationManager: operationManager,
            signer: signer
        )
    }

    private func provideConfirmationModel() {
        let rewardDestination: RewardDestination<DisplayAddress> = {
            switch nomination.bonding.rewardDestination {
            case .restake:
                return .restake
            case let .payout(account):
                let displayAddress = DisplayAddress(
                    address: account.address,
                    username: account.username
                )
                return .payout(account: displayAddress)
            }
        }()

        let confirmation = SelectValidatorsConfirmationModel(
            wallet: selectedAccount,
            amount: nomination.bonding.amount,
            rewardDestination: rewardDestination,
            targets: nomination.targets,
            maxTargets: nomination.maxTargets,
            hasExistingBond: false,
            hasExistingNomination: false
        )

        presenter.didReceiveModel(result: .success(confirmation))
    }

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        guard
            let amount = nomination.bonding.amount.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return nil
        }

        let controllerAddress = selectedAccount.address
        let rewardDestination = nomination.bonding.rewardDestination.accountAddress
        let targets = nomination.targets

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(
                amount: amount,
                controller: controllerAddress,
                rewardDestination: rewardDestination
            )

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        return closure
    }

    override func setup() {
        provideConfirmationModel()

        super.setup()
    }

    override func estimateFee() {
        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter.didReceive(feeError: error)
            }
        }
    }

    override func submitNomination() {
        guard !nomination.targets.isEmpty else {
            presenter.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)
            return
        }

        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        presenter.didStartNomination()

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(txHash):
                self?.presenter.didCompleteNomination(txHash: txHash)
            case let .failure(error):
                self?.presenter.didFailNomination(error: error)
            }
        }
    }
}
