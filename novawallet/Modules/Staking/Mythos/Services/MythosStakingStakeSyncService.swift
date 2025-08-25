import Foundation
import SubstrateSdk
import Operation_iOS

final class MythosStakingStakeSyncService: ObservableSubscriptionStateStore<MythosStakingStakeSyncService.State> {
    let accountId: AccountId

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId

        super.init(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chainId,
                chainRegistry: chainRegistry
            ),
            operationQueue: operationQueue,
            repository: repository,
            workQueue: workQueue,
            logger: logger
        )
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        [
            getUserStakeRequest(for: accountId),
            getSessionRequest()
        ]
    }
}

private extension MythosStakingStakeSyncService {
    func getUserStakeRequest(for accountId: AccountId) -> BatchStorageSubscriptionRequest {
        BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: MythosStakingPallet.userStakePath,
                localKey: "",
                keyParamClosure: {
                    BytesCodable(wrappedValue: accountId)
                }
            ),
            mappingKey: StateChange.Key.userStake.rawValue
        )
    }

    func getSessionRequest() -> BatchStorageSubscriptionRequest {
        BatchStorageSubscriptionRequest(
            innerRequest: UnkeyedSubscriptionRequest(
                storagePath: MythosStakingPallet.currentSessionPath,
                localKey: ""
            ),
            mappingKey: StateChange.Key.currentSession.rawValue
        )
    }
}

extension MythosStakingStakeSyncService {
    struct State: ObservableSubscriptionStateProtocol, Equatable {
        typealias TChange = StateChange

        let userStake: MythosStakingPallet.UserStake?
        let currentSession: SessionIndex
        let lastChange: TChange

        init(change: TChange) throws {
            userStake = try change.userStake.valueWhenDefinedElseThrow("userStake")
            currentSession = try change.currentSession.valueWhenDefinedElseThrow("session")
            lastChange = change
        }

        init(
            userStake: MythosStakingPallet.UserStake?,
            currentSession: SessionIndex,
            lastChange: TChange
        ) {
            self.userStake = userStake
            self.currentSession = currentSession
            self.lastChange = lastChange
        }

        func merging(change: TChange) -> Self {
            .init(
                userStake: change.userStake.valueWhenDefined(else: userStake),
                currentSession: change.currentSession.valueWhenDefined(else: currentSession),
                lastChange: change
            )
        }
    }

    struct StateChange: BatchStorageSubscriptionResult, Equatable {
        enum Key: String {
            case userStake
            case currentSession
        }

        let userStake: UncertainStorage<MythosStakingPallet.UserStake?>
        let currentSession: UncertainStorage<SessionIndex>
        let blockHash: Data?

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            userStake = try UncertainStorage(
                values: values,
                mappingKey: Key.userStake.rawValue,
                context: context
            )

            currentSession = try UncertainStorage<StringScaleMapper<SessionIndex>>(
                values: values,
                mappingKey: Key.currentSession.rawValue,
                context: context
            ).map(\.value)

            blockHash = try blockHashJson.map(to: Data?.self, with: context)
        }
    }
}
