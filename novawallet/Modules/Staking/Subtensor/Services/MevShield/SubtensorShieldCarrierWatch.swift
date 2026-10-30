import Foundation
import Operation_iOS
import SubstrateSdk

enum SubtensorShieldCarrierWatchResult {
    case included(blockHash: BlockHash)
    case rejected(Error)
    case lost
}

protocol SubtensorShieldCarrierWatchingProtocol {
    func createWatchOperation(for extrinsic: Data) -> BaseOperation<SubtensorShieldCarrierWatchResult>
}

final class SubtensorShieldCarrierWatch {
    let connection: JSONRPCEngine

    init(connection: JSONRPCEngine) {
        self.connection = connection
    }
}

private extension SubtensorShieldCarrierWatch {
    enum Constants {
        static let definitiveRejectionCodes: Set<Int> = [1010, 1011, 1012, 1013, 1014, 1016]
    }

    static func isDefinitiveRejection(_ error: Error) -> Bool {
        guard let rpcError = error as? JSONRPCError else {
            return false
        }

        return Constants.definitiveRejectionCodes.contains(rpcError.code)
    }
}

extension SubtensorShieldCarrierWatch: SubtensorShieldCarrierWatchingProtocol {
    func createWatchOperation(for extrinsic: Data) -> BaseOperation<SubtensorShieldCarrierWatchResult> {
        let state = SubtensorShieldCarrierWatchState()

        return AsyncClosureOperation(
            operationClosure: { [connection] completion in
                state.begin(with: completion)

                let updateClosure: (ExtrinsicSubscriptionUpdate) -> Void = { update in
                    let statusUpdate = ExtrinsicStatusUpdate(extrinsicHash: "", extrinsicStatus: update.params.result)

                    if let blockHash = statusUpdate.getInBlockOrFinalizedHash() {
                        state.finish(with: .included(blockHash: blockHash), connection: connection)
                    } else if statusUpdate.getFinalExtrinsicFailure() != nil {
                        state.finish(with: .lost, connection: connection)
                    } else {
                        state.markAccepted()
                    }
                }

                let failureClosure: (Error, Bool) -> Void = { error, _ in
                    let isRejected = !state.isAccepted && Self.isDefinitiveRejection(error)
                    state.finish(with: isRejected ? .rejected(error) : .lost, connection: connection)
                }

                let identifier = try connection.subscribe(
                    RPCMethod.submitAndWatchExtrinsic,
                    params: [extrinsic.toHex(includePrefix: true)],
                    updateClosure: updateClosure,
                    failureClosure: failureClosure
                )

                state.store(subscriptionId: identifier, connection: connection)
            },
            cancelationClosure: { [connection] in
                state.cancel(connection: connection)
            }
        )
    }
}

private final class SubtensorShieldCarrierWatchState {
    private let mutex = NSLock()
    private var accepted = false
    private var finished = false
    private var subscriptionId: UInt16?
    private var completion: ((Result<SubtensorShieldCarrierWatchResult, Error>) -> Void)?

    var isAccepted: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return accepted
    }

    func begin(with completion: @escaping (Result<SubtensorShieldCarrierWatchResult, Error>) -> Void) {
        mutex.lock()

        self.completion = completion

        mutex.unlock()
    }

    func markAccepted() {
        mutex.lock()

        accepted = true

        mutex.unlock()
    }

    func store(subscriptionId: UInt16, connection: JSONRPCEngine) {
        mutex.lock()

        guard !finished else {
            mutex.unlock()
            connection.cancelForIdentifier(subscriptionId)
            return
        }

        self.subscriptionId = subscriptionId

        mutex.unlock()
    }

    func finish(with result: SubtensorShieldCarrierWatchResult, connection: JSONRPCEngine) {
        mutex.lock()

        guard !finished else {
            mutex.unlock()
            return
        }

        finished = true

        let currentCompletion = completion
        let currentSubscriptionId = subscriptionId

        completion = nil
        subscriptionId = nil

        mutex.unlock()

        if let currentSubscriptionId {
            connection.cancelForIdentifier(currentSubscriptionId)
        }

        currentCompletion?(.success(result))
    }

    func cancel(connection: JSONRPCEngine) {
        mutex.lock()

        finished = true
        completion = nil

        let currentSubscriptionId = subscriptionId
        subscriptionId = nil

        mutex.unlock()

        if let currentSubscriptionId {
            connection.cancelForIdentifier(currentSubscriptionId)
        }
    }
}
