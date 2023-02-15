import Foundation
import SubstrateSdk
import RobinHood

extension Gov2SubscriptionFactory {
    func fetchTracksAndSubscribeVotes(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) {
        let cancellableKey = "tracks"

        if cancellables[cancellableKey] != nil {
            return
        }

        let tracksWrapper = operationFactory.fetchAllTracks(runtimeProvider: runtimeProvider)

        tracksWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard tracksWrapper === self?.cancellables[cancellableKey] else {
                    return
                }

                self?.cancellables[cancellableKey] = nil

                do {
                    let tracks = try tracksWrapper.targetOperation.extractNoCancellableResultData()
                    let trackIds = Set(tracks.map { Referenda.TrackId($0.trackId) })
                    self?.possibleTrackIds = trackIds

                    self?.subscribeAllVotesForPossibleTracks(
                        trackIds,
                        connection: connection,
                        runtimeProvider: runtimeProvider
                    )
                } catch {
                    self?.clearPendingSubscription(with: error)
                }
            }
        }

        cancellables[cancellableKey] = tracksWrapper

        operationQueue.addOperations(tracksWrapper.allOperations, waitUntilFinished: false)
    }

    func subscribeAllVotesForPossibleTracks(
        _ tracks: Set<Referenda.TrackId>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) {
        let currentParams = pendingVotesSubscriptions
        pendingVotesSubscriptions = []

        for params in currentParams {
            if let subscriptionWrapper = votes[params.accountId] {
                finalizeSubscription(
                    subscriptionWrapper,
                    target: params.target,
                    notificationClosure: params.notificationClosure
                )
            } else {
                let requests = tracks.map { trackId in
                    DoubleMapSubscriptionRequest(
                        storagePath: ConvictionVoting.votingFor,
                        localKey: "",
                        keyParamClosure: {
                            (BytesCodable(wrappedValue: params.accountId), StringScaleMapper(value: trackId))
                        },
                        param1Encoder: nil,
                        param2Encoder: nil
                    )
                }

                let subscription = CallbackBatchStorageSubscription<BatchSubscriptionHandler>(
                    requests: requests,
                    connection: connection,
                    runtimeService: runtimeProvider,
                    repository: nil,
                    operationQueue: operationQueue,
                    callbackQueue: .main
                ) { [weak self] result in
                    self?.handleVotesResult(
                        result,
                        connection: connection,
                        runtimeProvider: runtimeProvider,
                        accountId: params.accountId
                    )
                }

                let subscriptionWrapper = VotesWrapper(subscription: subscription)
                votes[params.accountId] = subscriptionWrapper

                subscription.subscribe()

                finalizeSubscription(
                    subscriptionWrapper,
                    target: params.target,
                    notificationClosure: params.notificationClosure
                )
            }
        }
    }

    func handleVotesResult(
        _ result: Result<BatchSubscriptionHandler, Error>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        accountId: AccountId
    ) {
        guard let wrapper = votes[accountId] else {
            return
        }

        switch result {
        case let .success(result):
            handleVotes(
                for: accountId,
                connection: connection,
                runtimeProvider: runtimeProvider,
                blockHash: result.blockHash
            )
        case let .failure(error):
            wrapper.state = NotEqualWrapper(value: .failure(error))
        }
    }

    func fetchTrackLocksWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[ConvictionVoting.ClassLock]?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<[ConvictionVoting.ClassLock]>]> =
            operationFactory.requestFactory.queryItems(
                engine: connection,
                keyParams: {
                    [BytesCodable(wrappedValue: accountId)]
                },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: ConvictionVoting.trackLocksFor,
                at: blockHash
            )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[ConvictionVoting.ClassLock]?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation] + wrapper.allOperations
        )
    }

    func handleVotes(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) {
        let cancellableKey = "votes-\(accountId.toHex())"
        clear(cancellable: &cancellables[cancellableKey])

        let trackLocksWrapper = fetchTrackLocksWrapper(
            for: accountId,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        let votesWrapper = operationFactory.fetchAccountVotesWrapper(
            for: accountId,
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        let mapOperation = ClosureOperation<CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>> {
            let accountVoting = try votesWrapper.targetOperation.extractNoCancellableResultData()
            let trackLocks = try trackLocksWrapper.targetOperation.extractNoCancellableResultData()
            return CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>(
                value: .init(votes: accountVoting, trackLocks: trackLocks ?? []),
                blockHash: blockHash
            )
        }

        let dependencies = trackLocksWrapper.allOperations + votesWrapper.allOperations
        mapOperation.addDependency(votesWrapper.targetOperation)
        mapOperation.addDependency(trackLocksWrapper.targetOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.cancellables[cancellableKey] else {
                    return
                }

                self?.cancellables[cancellableKey] = nil

                do {
                    let value = try mapOperation.extractNoCancellableResultData()
                    self?.votes[accountId]?.state = NotEqualWrapper(value: .success(value))
                } catch {
                    self?.votes[accountId]?.state = NotEqualWrapper(value: .failure(error))
                }
            }
        }

        cancellables[cancellableKey] = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func finalizeSubscription(
        _ subscriptionWrapper: VotesWrapper,
        target: AnyObject,
        notificationClosure: @escaping (ReferendumVotesSubscriptionResult?) -> Void
    ) {
        notificationClosure(subscriptionWrapper.state?.value)

        subscriptionWrapper.addObserver(with: target) { _, newValueWrapper in
            notificationClosure(newValueWrapper?.value)
        }
    }

    func clearPendingSubscription(with error: Error) {
        let currentParams = pendingVotesSubscriptions
        pendingVotesSubscriptions = []

        for params in currentParams {
            params.notificationClosure(.failure(error))
        }
    }
}
