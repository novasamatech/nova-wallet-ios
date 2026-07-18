import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

protocol PolkadotStakersRewardFactoryProtocol {
    func createStakersRewardWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BigUInt>
}

enum StakingViewFunction {
    static let executeCallName = "RuntimeViewFunction_execute_view_function"

    /// `Staking::era_reward_allocation(era)` view function id. FRAME view function ids are
    /// `twox128(pallet_name) ++ twox128("fn_name(arg_types) -> return_type")` — derived from the
    /// method signature the same way storage keys derive from pallet/item names, so the id is
    /// identical on every chain running the pallet and only changes if the signature changes.
    static func eraRewardAllocationCallId() throws -> Data {
        let signature = "era_reward_allocation(EraIndex) -> crate::reward::EraRewardAllocation<BalanceOf<T>>"

        guard
            let palletData = "Staking".data(using: .utf8),
            let signatureData = signature.data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        return palletData.twox128() + signatureData.twox128()
    }
}

/// Per-era reward allocation as recorded by the staking pallet at era end.
/// `stakerRewards` mirrors `Staking.ErasValidatorReward` — the exact amount payouts
/// distribute to stakers (nominators + validators) for the era. `validatorIncentive`
/// is the DAP validator self-stake incentive paid to validator stashes only, so it
/// must not be counted into the nominator-facing return.
struct StakingEraRewardAllocation: Equatable {
    let stakerRewards: BigUInt
    let validatorIncentive: BigUInt
}

extension StakingEraRewardAllocation {
    enum DecoderError: Error {
        case viewFunctionFailed(variant: UInt8)
    }

    /// Decodes the `Result<Vec<u8>, ViewFunctionDispatchError>` envelope returned by
    /// `RuntimeViewFunction_execute_view_function` and then the inner
    /// `EraRewardAllocation { staker_rewards: u128, validator_incentive: u128 }`.
    /// Static coding is used deliberately: view function ids and types ship with metadata v16,
    /// which is above the version the app requests.
    struct StateCallDecoder: StateCallStaticResultDecoding {
        typealias Result = StakingEraRewardAllocation

        func decode(data: Data) throws -> StakingEraRewardAllocation {
            let envelopeDecoder = try ScaleDecoder(data: data)

            let resultVariant = try envelopeDecoder.readAndConfirm(count: 1)

            guard resultVariant.first == 0 else {
                throw DecoderError.viewFunctionFailed(variant: resultVariant.first ?? .max)
            }

            let payload = try Data(scaleDecoder: envelopeDecoder)
            let payloadDecoder = try ScaleDecoder(data: payload)

            let stakerRewards = try payloadDecoder.readAndConfirm(count: 16)
            let validatorIncentive = try payloadDecoder.readAndConfirm(count: 16)

            return StakingEraRewardAllocation(
                stakerRewards: BigUInt(Data(stakerRewards.reversed())),
                validatorIncentive: BigUInt(Data(validatorIncentive.reversed()))
            )
        }
    }
}

enum PolkadotStakersRewardError: Error {
    case noCompletedEra
    case emptyStakersReward
}

/// Fetches the amount of DOT allocated to stakers in the last completed era via the staking
/// pallet's `era_reward_allocation` view function. Post-DAP this is the fixed staker allocation
/// of the period mint (currently 45.2%), so it is the correct, self-updating basis for the
/// staking APY — unlike the `Inflation` runtime API, whose `next_mint` reports the full mint
/// before the DAP split.
final class PolkadotStakersRewardFactory {
    let operationQueue: OperationQueue
    let storageRequestFactory: StorageRequestFactoryProtocol
    let stateCallFactory: StateCallRequestFactoryProtocol
    let keyFactory: StorageKeyFactoryProtocol

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
        keyFactory = StorageKeyFactory()
        storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        stateCallFactory = StateCallRequestFactory()
    }
}

extension PolkadotStakersRewardFactory: PolkadotStakersRewardFactoryProtocol {
    func createStakersRewardWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<BigUInt> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        // 1. Resolve the active era.
        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<Staking.ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try self.keyFactory.activeEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Staking.activeEra
            )

        activeEraWrapper.addDependency(operations: [codingFactoryOperation])

        // 2. Query `Staking::era_reward_allocation` for the last *completed* era (activeEra - 1) —
        //    the allocation is snapshotted at era end, so the active era itself reads zero.
        let allocationWrapper: CompoundOperationWrapper<StakingEraRewardAllocation> =
            stateCallFactory.createStaticCodingWrapper(
                for: StakingViewFunction.executeCallName,
                paramsClosure: {
                    let activeEra = try activeEraWrapper.targetOperation
                        .extractNoCancellableResultData()
                        .first?.value?.index ?? 0

                    guard activeEra > 0 else {
                        throw PolkadotStakersRewardError.noCompletedEra
                    }

                    let callId = try StakingViewFunction.eraRewardAllocationCallId()
                    let eraArgument = try UInt32(activeEra - 1).scaleEncoded()

                    // the view function's arguments are passed as a SCALE `Vec<u8>`
                    return try callId + eraArgument.scaleEncoded()
                },
                connection: connection,
                decoder: StakingEraRewardAllocation.StateCallDecoder(),
                at: nil
            )

        allocationWrapper.addDependency(wrapper: activeEraWrapper)

        // 3. Extract the stakers' part. A zero allocation means the era was not recorded in
        //    DAP mode — treat as an error so the sync service retries instead of showing 0%.
        let mapOperation = ClosureOperation<BigUInt> {
            let allocation = try allocationWrapper.targetOperation.extractNoCancellableResultData()

            guard allocation.stakerRewards > 0 else {
                throw PolkadotStakersRewardError.emptyStakersReward
            }

            return allocation.stakerRewards
        }

        mapOperation.addDependency(allocationWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [codingFactoryOperation]
                + activeEraWrapper.allOperations
                + allocationWrapper.allOperations
        )
    }
}
