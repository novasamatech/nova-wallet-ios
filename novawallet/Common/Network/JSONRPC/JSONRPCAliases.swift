import Foundation
import Operation_iOS
import SubstrateSdk

typealias RuntimeVersionUpdate = JSONRPCSubscriptionUpdate<RuntimeVersion>
typealias StorageSubscriptionUpdate = JSONRPCSubscriptionUpdate<StorageUpdate>
typealias ExtrinsicSubscriptionUpdate = JSONRPCSubscriptionUpdate<ExtrinsicStatus>
typealias JSONRPCQueryOperation = JSONRPCOperation<StorageQuery, [StorageUpdate]>
typealias SuperIdentityOperation = BaseOperation<[StorageResponse<SuperIdentity>]>
typealias SuperIdentityWrapper = CompoundOperationWrapper<[StorageResponse<SuperIdentity>]>
typealias IdentityOperation = BaseOperation<[StorageResponse<Identity>]>
typealias IdentityWrapper = CompoundOperationWrapper<[StorageResponse<Identity>]>
typealias SlashingSpansWrapper = CompoundOperationWrapper<[StorageResponse<Staking.SlashingSpans>]>
typealias UnappliedSlashesOperation = BaseOperation<[StorageResponse<[Staking.UnappliedSlash]>]>
typealias UnappliedSlashesWrapper = CompoundOperationWrapper<[StorageResponse<[Staking.UnappliedSlash]>]>
