import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

enum BlockFinalityOperationFactoryError: Error {
    case blockNotCanonical(BlockHash)
}

protocol BlockFinalityOperationFactoryProtocol {
    func createFinalityWrapper(
        for blockHash: BlockHash,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Void>
}

final class BlockFinalityOperationFactory {
    private let blockHashOperationFactory = BlockHashOperationFactory()
}

private extension BlockFinalityOperationFactory {
    func createHeightWrapper(
        of blockHash: BlockHash,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<BlockNumber> {
        let headerOperation = JSONRPCListOperation<Block.Header>(
            engine: connection,
            method: RPCMethod.getBlockHeader,
            parameters: [blockHash],
            timeout: JSONRPCTimeout.singleNode
        )

        let headerWrapper = CompoundOperationWrapper(targetOperation: headerOperation)

        return BlockNumberOperationFactory.createWrapper(for: headerWrapper)
    }

    func createFinalizedHeightOperation(
        connection: JSONRPCEngine,
        heightClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<BlockNumber> {
        let headsSubscription = FinalizedHeightSubscription(connection: connection)

        return AsyncClosureOperation(
            operationClosure: { completion in
                try headsSubscription.subscribe(reaching: heightClosure(), completion: completion)
            },
            cancelationClosure: {
                headsSubscription.unsubscribe()
            }
        )
    }
}

extension BlockFinalityOperationFactory: BlockFinalityOperationFactoryProtocol {
    func createFinalityWrapper(
        for blockHash: BlockHash,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Void> {
        let heightWrapper = createHeightWrapper(of: blockHash, connection: connection)

        let finalizedHeightOperation = createFinalizedHeightOperation(connection: connection) {
            try heightWrapper.targetOperation.extractNoCancellableResultData()
        }

        finalizedHeightOperation.addDependency(heightWrapper.targetOperation)

        let canonicalHashOperation = blockHashOperationFactory.createBlockHashOperation(
            connection: connection,
            timeout: JSONRPCTimeout.singleNode
        ) {
            try finalizedHeightOperation.extractNoCancellableResultData()
        }

        canonicalHashOperation.addDependency(finalizedHeightOperation)

        let checkOperation = ClosureOperation<Void> {
            let canonicalHash = try canonicalHashOperation.extractNoCancellableResultData()

            guard try Data(hexString: canonicalHash) == Data(hexString: blockHash) else {
                throw BlockFinalityOperationFactoryError.blockNotCanonical(blockHash)
            }
        }

        checkOperation.addDependency(canonicalHashOperation)

        return CompoundOperationWrapper(
            targetOperation: checkOperation,
            dependencies: heightWrapper.allOperations + [finalizedHeightOperation, canonicalHashOperation]
        )
    }
}

private final class FinalizedHeightSubscription {
    private enum Constants {
        static let subscribeMethod = "chain_subscribeFinalizedHeads"
        static let unsubscribeMethod = "chain_unsubscribeFinalizedHeads"
    }

    let connection: JSONRPCEngine

    private let mutex = NSLock()
    private var subscriptionId: UInt16?
    private var isActive = true

    init(connection: JSONRPCEngine) {
        self.connection = connection
    }

    func subscribe(
        reaching height: BlockNumber,
        completion: @escaping (Result<BlockNumber, Error>) -> Void
    ) throws {
        let updateClosure: (FinalizedHeadUpdate) -> Void = { [weak self] update in
            guard
                let finalizedHeight = BigUInt.fromHexString(update.params.result.number),
                finalizedHeight >= BigUInt(height),
                self?.deactivate() == true else {
                return
            }

            completion(.success(height))
        }

        let failureClosure: (Error, Bool) -> Void = { [weak self] error, _ in
            guard self?.deactivate() == true else {
                return
            }

            completion(.failure(error))
        }

        let identifier = try connection.subscribe(
            Constants.subscribeMethod,
            params: [String](),
            unsubscribeMethod: Constants.unsubscribeMethod,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )

        store(subscriptionId: identifier)
    }

    func unsubscribe() {
        deactivate()
    }
}

private extension FinalizedHeightSubscription {
    func store(subscriptionId identifier: UInt16) {
        mutex.lock()

        guard isActive else {
            mutex.unlock()
            connection.cancelForIdentifier(identifier)
            return
        }

        subscriptionId = identifier

        mutex.unlock()
    }

    @discardableResult
    func deactivate() -> Bool {
        mutex.lock()

        guard isActive else {
            mutex.unlock()
            return false
        }

        isActive = false

        let identifier = subscriptionId
        subscriptionId = nil

        mutex.unlock()

        if let identifier {
            connection.cancelForIdentifier(identifier)
        }

        return true
    }
}
