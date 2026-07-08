import Foundation
import SubstrateSdk
import Operation_iOS

protocol ParachainAvnScheduledRequestsQueryWrapperFactoryProtocol {
    func createQueryWrapper<K1, K2>(
        using connection: JSONRPCEngine,
        with collators: @escaping () throws -> [K1],
        delegator: @escaping () throws -> K2,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<DelegationRequestsQueryResult> where K1: Encodable, K2: Encodable
}

extension ParachainAvnScheduledRequestsQueryWrapperFactoryProtocol {
    func createQueryWrapper<K1, K2>(
        using connection: JSONRPCEngine,
        with collators: @escaping () throws -> [K1],
        delegator: @escaping () throws -> K2,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        at blockHash: Data? = nil
    ) -> CompoundOperationWrapper<DelegationRequestsQueryResult> where K1: Encodable, K2: Encodable {
        createQueryWrapper(
            using: connection,
            with: collators,
            delegator: delegator,
            codingFactory: codingFactory,
            at: blockHash
        )
    }
}

/// EWX-specific scheduled-requests query factory.
///
/// Identical structure to the Moonbeam `ParaStkScheduledRequestsQueryWrapperFactory`
/// but routes runtime metadata lookups and storage queries through
/// `ParachainAvn.nominationScheduledRequestsPath` instead of
/// `ParachainStaking.delegationRequestsPath`. The Moonbeam factory's
/// hardcoded path throws `storageMetadataNotFound` on EWX because that
/// runtime exposes `NominationScheduledRequests`, not
/// `DelegationScheduledRequests`.
final class ParachainAvnScheduledRequestsQueryWrapperFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
    }
}

extension ParachainAvnScheduledRequestsQueryWrapperFactory: ParachainAvnScheduledRequestsQueryWrapperFactoryProtocol {
    func createQueryWrapper<K1, K2>(
        using connection: JSONRPCEngine,
        with collators: @escaping () throws -> [K1],
        delegator: @escaping () throws -> K2,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<DelegationRequestsQueryResult> where K1: Encodable, K2: Encodable {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let codingFactory = try codingFactory()
            let metadata = codingFactory.metadata

            let storageMetadata = metadata.getStorageMetadata(
                for: ParachainAvn.nominationScheduledRequestsPath
            )

            guard let storageMetadata else { throw ParaStkRequestsQueryError.storageMetadataNotFound }

            return switch storageMetadata.type {
            case .map:
                storageRequestFactory.queryItems(
                    engine: connection,
                    keyParams: collators,
                    factory: { codingFactory },
                    storagePath: ParachainAvn.nominationScheduledRequestsPath,
                    at: blockHash
                )
            case .doubleMap:
                storageRequestFactory.queryItems(
                    engine: connection,
                    keyParams1: collators,
                    keyParams2: { try Array(repeating: try delegator(), count: collators().count) },
                    factory: { codingFactory },
                    storagePath: ParachainAvn.nominationScheduledRequestsPath,
                    at: blockHash
                )
            default:
                throw ParaStkRequestsQueryError.unexpectedStorageType
            }
        }
    }
}
