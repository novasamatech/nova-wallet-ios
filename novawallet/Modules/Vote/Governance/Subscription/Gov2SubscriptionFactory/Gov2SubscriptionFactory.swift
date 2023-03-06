import Foundation
import SubstrateSdk
import RobinHood

final class Gov2SubscriptionFactory: AnyCancellableCleaning {
    typealias ReferendumState = NotEqualWrapper<ReferendumSubscriptionResult>
    typealias VotesState = NotEqualWrapper<ReferendumVotesSubscriptionResult>
    typealias ReferendumWrapper = StorageSubscriptionObserver<ReferendumInfo, ReferendumState>
    typealias VotesWrapper = BatchStorageSubscriptionObserver<BatchSubscriptionHandler, VotesState>

    struct VotesSubscriptionParams {
        let target: AnyObject
        let accountId: AccountId
        let notificationClosure: (ReferendumVotesSubscriptionResult?) -> Void
    }

    var referendums: [ReferendumIdLocal: ReferendumWrapper] = [:]

    var votes: [AccountId: VotesWrapper] = [:]
    var pendingVotesSubscriptions: [VotesSubscriptionParams] = []
    var possibleTrackIds: Set<Referenda.TrackId>?

    var cancellables: [String: CancellableCall] = [:]

    let operationFactory: Gov2OperationFactory
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let chainId: ChainModel.Id

    init(
        chainId: ChainModel.Id,
        operationFactory: Gov2OperationFactory,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.operationFactory = operationFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

extension Gov2SubscriptionFactory: GovernanceSubscriptionFactoryProtocol {
    func cancelCancellable() {
        let keys = cancellables.keys

        for key in keys {
            clear(cancellable: &cancellables[key])
        }

        pendingVotesSubscriptions = []
    }

    func subscribeToReferendum(
        _ target: AnyObject,
        referendumIndex: ReferendumIdLocal,
        notificationClosure: @escaping (ReferendumSubscriptionResult?) -> Void
    ) {
        let subscriptionWrapper: ReferendumWrapper

        if let wrapper = referendums[referendumIndex] {
            subscriptionWrapper = wrapper
        } else {
            let request = MapSubscriptionRequest(storagePath: Referenda.referendumInfo, localKey: "") {
                StringScaleMapper(value: referendumIndex)
            }

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                notificationClosure(.failure(ChainRegistryError.connectionUnavailable))
                return
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                notificationClosure(.failure(ChainRegistryError.runtimeMetadaUnavailable))
                return
            }

            let subscription = CallbackStorageSubscription<ReferendumInfo>(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackWithBlockQueue: .main
            ) { [weak self] result in
                self?.handleReferendumResult(
                    result,
                    connection: connection,
                    runtimeProvider: runtimeProvider,
                    referendumIndex: referendumIndex
                )
            }

            subscriptionWrapper = ReferendumWrapper(subscription: subscription)
            referendums[referendumIndex] = subscriptionWrapper
        }

        notificationClosure(subscriptionWrapper.state?.value)

        subscriptionWrapper.addObserver(with: target) { _, newValueWrapper in
            notificationClosure(newValueWrapper?.value)
        }
    }

    func unsubscribeFromReferendum(_: AnyObject, referendumIndex: ReferendumIdLocal) {
        guard let subscriptionWrapper = referendums[referendumIndex] else {
            return
        }

        subscriptionWrapper.removeObserver(by: self)

        if subscriptionWrapper.observers.isEmpty {
            referendums[referendumIndex] = nil
        }
    }

    func subscribeToAccountVotes(
        _ target: AnyObject,
        accountId: AccountId,
        notificationClosure: @escaping (ReferendumVotesSubscriptionResult?) -> Void
    ) {
        if let wrapper = votes[accountId] {
            finalizeSubscription(
                wrapper,
                target: target,
                notificationClosure: notificationClosure
            )
        } else {
            guard let connection = chainRegistry.getConnection(for: chainId) else {
                notificationClosure(.failure(ChainRegistryError.connectionUnavailable))
                return
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                notificationClosure(.failure(ChainRegistryError.runtimeMetadaUnavailable))
                return
            }

            pendingVotesSubscriptions.append(
                .init(target: target, accountId: accountId, notificationClosure: notificationClosure)
            )

            if let trackIds = possibleTrackIds {
                subscribeAllVotesForPossibleTracks(
                    trackIds,
                    connection: connection,
                    runtimeProvider: runtimeProvider
                )
            } else {
                fetchTracksAndSubscribeVotes(
                    for: connection,
                    runtimeProvider: runtimeProvider
                )
            }
        }
    }

    func unsubscribeFromAccountVotes(_: AnyObject, accountId: AccountId) {
        guard let subscriptionWrapper = votes[accountId] else {
            return
        }

        subscriptionWrapper.removeObserver(by: self)

        if subscriptionWrapper.observers.isEmpty {
            votes[accountId]?.subscription.unsubscribe()
            votes[accountId] = nil
        }
    }
}
