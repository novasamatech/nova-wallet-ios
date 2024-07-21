import Foundation
import SubstrateSdk

extension NominationPools {
    static func migrateIfNeeded(
        _ needsMigration: Bool,
        accountId: AccountId,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        if needsMigration {
            return try builder.adding(
                call: NominationPools.MigrateCall(
                    memberAccount: .accoundId(accountId)
                ).runtimeCall()
            ).with(batchType: .ignoreFails)
        } else {
            return builder
        }
    }
}
