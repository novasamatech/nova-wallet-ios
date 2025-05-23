import Foundation
import Operation_iOS
import Keystore_iOS

final class InitiatedBondingConfirmInteractor: SelectValidatorsConfirmInteractorBase {
    let nomination: PreparedNomination<InitiatedBonding>
    let selectedAccount: WalletDisplayAddress

    init(
        selectedAccount: WalletDisplayAddress,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        nomination: PreparedNomination<InitiatedBonding>,
        currencyManager: CurrencyManagerProtocol
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
            signer: signer,
            currencyManager: currencyManager
        )
    }

    private func provideConfirmationModel() {
        let rewardDestination: RewardDestination<DisplayAddress> = {
            switch nomination.bonding.rewardDestination {
            case .restake:
                return .restake
            case let .payout(account):
                let displayAddress = DisplayAddress(
                    address: account.toAddress() ?? "",
                    username: account.name
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

    private func createExtrinsicBuilderClosure(
        for coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicBuilderClosure? {
        guard
            let amount = nomination.bonding.amount.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ),
            let rewardDestination = nomination.bonding.rewardDestination.accountAddress else {
            return nil
        }

        let controllerAddress = selectedAccount.address
        let targets = nomination.targets

        let closure: ExtrinsicBuilderClosure = { builder in
            let controller = try controllerAddress.toAccountId()
            let payee = try Staking.RewardDestinationArg(rewardDestination: rewardDestination)

            let bondClosure = try Staking.Bond.appendCall(
                for: .accoundId(controller),
                value: amount,
                payee: payee,
                codingFactory: coderFactory
            )

            let callFactory = SubstrateCallFactory()

            let nominateCall = try callFactory.nominate(targets: targets)

            return try bondClosure(builder).adding(call: nominateCall)
        }

        return closure
    }

    override func setup() {
        provideConfirmationModel()

        super.setup()
    }

    override func estimateFee() {
        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                guard
                    let closure = self?.createExtrinsicBuilderClosure(
                        for: coderFactory
                    ) else {
                    return
                }

                self?.extrinsicService.estimateFee(closure, runningIn: .main) { result in
                    switch result {
                    case let .success(info):
                        self?.presenter.didReceive(paymentInfo: info)
                    case let .failure(error):
                        self?.presenter.didReceive(feeError: error)
                    }
                }
            }, errorClosure: { [weak self] error in
                self?.presenter.didReceive(feeError: error)
            }
        )
    }

    override func submitNomination() {
        presenter.didStartNomination()

        guard !nomination.targets.isEmpty else {
            presenter.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)
            return
        }

        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                guard
                    let closure = self?.createExtrinsicBuilderClosure(for: coderFactory),
                    let signer = self?.signer else {
                    return
                }

                self?.extrinsicService.submit(
                    closure,
                    signer: signer,
                    runningIn: .main
                ) { result in
                    switch result {
                    case let .success(txHash):
                        self?.presenter.didCompleteNomination(txHash: txHash)
                    case let .failure(error):
                        self?.presenter.didFailNomination(error: error)
                    }
                }
            }, errorClosure: { [weak self] error in
                self?.presenter.didFailNomination(error: error)
            }
        )
    }
}
