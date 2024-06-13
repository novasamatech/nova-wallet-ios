import Foundation
import Operation_iOS
import BigInt

protocol StartStakingExtrinsicProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        stakingOption: SelectedStakingOption,
        amount: BigUInt,
        feeId: TransactionFeeId
    )

    func submit(
        using service: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        stakingOption: SelectedStakingOption,
        amount: BigUInt,
        closure: @escaping ExtrinsicSubmitClosure
    )
}

extension StartStakingExtrinsicProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        stakingOption: SelectedStakingOption,
        amount: BigUInt
    ) {
        let feeId = StartStakingFeeIdFactory.generateFeeId(for: stakingOption, amount: amount)

        estimateFee(
            using: service,
            feeProxy: feeProxy,
            stakingOption: stakingOption,
            amount: amount,
            feeId: feeId
        )
    }
}

final class StartStakingExtrinsicProxy {
    struct DirectStakingParams {
        let controller: AccountId
        let validators: PreparedValidators
        let amount: BigUInt
    }

    struct PoolStakingParams {
        let pool: NominationPools.SelectedPool
        let amount: BigUInt
    }

    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let selectedAccount: ChainAccountResponse

    init(
        selectedAccount: ChainAccountResponse,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }

    private func createDirectStakingBuilderClosure(
        for params: DirectStakingParams,
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let bondClosure = try Staking.Bond.appendCall(
                for: .accoundId(params.controller),
                value: params.amount,
                payee: .staked,
                codingFactory: coderFactory
            )

            let callFactory = SubstrateCallFactory()

            let targets = params.validators.targets
            let nominateCall = try callFactory.nominate(targets: targets)

            return try bondClosure(builder).adding(call: nominateCall)
        }
    }

    private func createPoolStakingBuilderClosure(
        for params: PoolStakingParams
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let call = NominationPools.JoinCall(amount: params.amount, poolId: params.pool.poolId)

            return try builder.adding(call: call.runtimeCall())
        }
    }

    private func estimateDirectStakingFee(
        service: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        params: DirectStakingParams,
        feeId: TransactionFeeId,
        coderFactory: RuntimeCoderFactoryProtocol
    ) {
        let closure = createDirectStakingBuilderClosure(
            for: params,
            coderFactory: coderFactory
        )

        feeProxy.estimateFee(
            using: service,
            reuseIdentifier: feeId,
            setupBy: closure
        )
    }

    private func estimatePoolStakingFee(
        service: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        params: PoolStakingParams,
        feeId: TransactionFeeId
    ) {
        let closure = createPoolStakingBuilderClosure(for: params)

        feeProxy.estimateFee(
            using: service,
            reuseIdentifier: feeId,
            setupBy: closure
        )
    }

    private func submitDirectStaking(
        service: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        params: DirectStakingParams,
        coderFactory: RuntimeCoderFactoryProtocol,
        closure: @escaping ExtrinsicSubmitClosure
    ) {
        let builderClosure = createDirectStakingBuilderClosure(
            for: params,
            coderFactory: coderFactory
        )

        service.submit(
            builderClosure,
            signer: signer,
            runningIn: .main,
            completion: closure
        )
    }

    private func submitPoolStaking(
        service: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        params: PoolStakingParams,
        closure: @escaping ExtrinsicSubmitClosure
    ) {
        let builderClosure = createPoolStakingBuilderClosure(for: params)

        service.submit(
            builderClosure,
            signer: signer,
            runningIn: .main,
            completion: closure
        )
    }
}

extension StartStakingExtrinsicProxy: StartStakingExtrinsicProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        stakingOption: SelectedStakingOption,
        amount: BigUInt,
        feeId: TransactionFeeId
    ) {
        switch stakingOption {
        case let .direct(preparedValidators):
            let controller = selectedAccount.accountId

            runtimeService.fetchCoderFactory(
                runningIn: OperationManager(operationQueue: operationQueue),
                completion: { [weak self] coderFactory in
                    self?.estimateDirectStakingFee(
                        service: service,
                        feeProxy: feeProxy,
                        params: .init(controller: controller, validators: preparedValidators, amount: amount),
                        feeId: feeId,
                        coderFactory: coderFactory
                    )
                }, errorClosure: { error in
                    feeProxy.delegate?.didReceiveFee(result: .failure(error), for: feeId)
                }
            )
        case let .pool(selectedPool):
            estimatePoolStakingFee(
                service: service,
                feeProxy: feeProxy,
                params: .init(pool: selectedPool, amount: amount),
                feeId: feeId
            )
        }
    }

    func submit(
        using service: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        stakingOption: SelectedStakingOption,
        amount: BigUInt,
        closure: @escaping ExtrinsicSubmitClosure
    ) {
        switch stakingOption {
        case let .direct(preparedValidators):
            let controller = selectedAccount.accountId

            runtimeService.fetchCoderFactory(
                runningIn: OperationManager(operationQueue: operationQueue),
                completion: { [weak self] coderFactory in
                    self?.submitDirectStaking(
                        service: service,
                        signer: signer,
                        params: .init(
                            controller: controller,
                            validators: preparedValidators,
                            amount: amount
                        ),
                        coderFactory: coderFactory,
                        closure: closure
                    )
                }, errorClosure: { error in
                    closure(.failure(error))
                }
            )
        case let .pool(selectedPool):
            submitPoolStaking(
                service: service,
                signer: signer,
                params: .init(pool: selectedPool, amount: amount),
                closure: closure
            )
        }
    }
}
