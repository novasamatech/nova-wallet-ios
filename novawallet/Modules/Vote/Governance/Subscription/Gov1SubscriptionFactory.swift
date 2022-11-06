import Foundation
import SubstrateSdk
import RobinHood

final class Gov1SubscriptionFactory: AnyCancellableCleaning {
    typealias ReferendumState = NotEqualWrapper<ReferendumSubscriptionResult>
    typealias VotesState = NotEqualWrapper<ReferendumVotesSubscriptionResult>
    typealias VotesWrapper = StorageSubscriptionObserver<Democracy.Voting, VotesState>

    typealias ReferendumWrapper = StorageSubscriptionObserver<
        Democracy.ReferendumInfo, ReferendumState
    >

    private(set) var referendums: [ReferendumIdLocal: ReferendumWrapper] = [:]
    private(set) var votes: [AccountId: VotesWrapper] = [:]
    private(set) var cancellables: [String: CancellableCall] = [:]

    let operationFactory: Gov1OperationFactory
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let chainId: ChainModel.Id

    init(
        chainId: ChainModel.Id,
        operationFactory: Gov1OperationFactory,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.operationFactory = operationFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    private func handleReferendumResult(
        _ result: Result<CallbackStorageSubscriptionResult<Democracy.ReferendumInfo>, Error>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        referendumIndex: ReferendumIdLocal
    ) {
        guard let wrapper = referendums[referendumIndex] else {
            return
        }

        switch result {
        case let .success(result):
            if let referendumInfo = result.value {
                handleReferendum(
                    for: referendumInfo,
                    connection: connection,
                    runtimeProvider: runtimeProvider,
                    referendumIndex: referendumIndex,
                    blockHash: result.blockHash
                )
            } else {
                let value = CallbackStorageSubscriptionResult<ReferendumLocal>(value: nil, blockHash: nil)
                wrapper.state = NotEqualWrapper(value: .success(value))
            }
        case let .failure(error):
            wrapper.state = NotEqualWrapper(value: .failure(error))
        }
    }

    private func handleReferendum(
        for referendumInfo: Democracy.ReferendumInfo,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        referendumIndex: ReferendumIdLocal,
        blockHash: Data?
    ) {
        let cancellableKey = "referendum-\(referendumIndex)"
        clear(cancellable: &cancellables[cancellableKey])

        let wrapper = operationFactory.fetchReferendumWrapper(
            for: referendumInfo,
            index: referendumIndex,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.cancellables[cancellableKey] else {
                    return
                }

                self?.cancellables[cancellableKey] = nil

                do {
                    let referendum = try wrapper.targetOperation.extractNoCancellableResultData()
                    let value = CallbackStorageSubscriptionResult<ReferendumLocal>(
                        value: referendum,
                        blockHash: blockHash
                    )

                    self?.referendums[referendumIndex]?.state = NotEqualWrapper(value: .success(value))
                } catch {
                    self?.referendums[referendumIndex]?.state = NotEqualWrapper(value: .failure(error))
                }
            }
        }

        cancellables[cancellableKey] = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func handleVotesResult(
        _ result: Result<CallbackStorageSubscriptionResult<Democracy.Voting>, Error>,
        runtimeProvider: RuntimeProviderProtocol,
        accountId: AccountId
    ) {
        guard let wrapper = votes[accountId] else {
            return
        }

        switch result {
        case let .success(result):
            handleVotes(
                for: result.value,
                runtimeProvider: runtimeProvider,
                accountId: accountId,
                blockHash: result.blockHash
            )
        case let .failure(error):
            wrapper.state = NotEqualWrapper(value: .failure(error))
        }
    }

    private func handleVotes(
        for votes: Democracy.Voting?,
        runtimeProvider: RuntimeProviderProtocol,
        accountId: AccountId,
        blockHash: Data?
    ) {
        let cancellableKey = "votes-\(accountId.toHex())"
        clear(cancellable: &cancellables[cancellableKey])

        let wrapper = operationFactory.fetchTracksVotingWrapper(
            for: votes,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.cancellables[cancellableKey] else {
                    return
                }

                self?.cancellables[cancellableKey] = nil

                do {
                    let tracksVoting = try wrapper.targetOperation.extractNoCancellableResultData()
                    let value = CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>(
                        value: tracksVoting,
                        blockHash: blockHash
                    )

                    self?.votes[accountId]?.state = NotEqualWrapper(value: .success(value))
                } catch {
                    self?.votes[accountId]?.state = NotEqualWrapper(value: .failure(error))
                }
            }
        }

        cancellables[cancellableKey] = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension Gov1SubscriptionFactory: GovernanceSubscriptionFactoryProtocol {
    func subscribeToReferendum(
        _ target: AnyObject,
        referendumIndex: UInt,
        notificationClosure: @escaping (ReferendumSubscriptionResult?) -> Void
    ) {
        let subscriptionWrapper: ReferendumWrapper

        if let wrapper = referendums[referendumIndex] {
            subscriptionWrapper = wrapper
        } else {
            let request = MapSubscriptionRequest(storagePath: Democracy.referendumInfo, localKey: "") {
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

            let subscription = CallbackStorageSubscription<Democracy.ReferendumInfo>(
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
        let subscriptionWrapper: VotesWrapper

        if let wrapper = votes[accountId] {
            subscriptionWrapper = wrapper
        } else {
            let request = MapSubscriptionRequest(storagePath: Democracy.votingOf, localKey: "") {
                BytesCodable(wrappedValue: accountId)
            }

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                notificationClosure(.failure(ChainRegistryError.connectionUnavailable))
                return
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                notificationClosure(.failure(ChainRegistryError.runtimeMetadaUnavailable))
                return
            }

            let subscription = CallbackStorageSubscription<Democracy.Voting>(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackWithBlockQueue: .main
            ) { [weak self] result in
                self?.handleVotesResult(
                    result,
                    runtimeProvider: runtimeProvider,
                    accountId: accountId
                )
            }

            subscriptionWrapper = VotesWrapper(subscription: subscription)
            votes[accountId] = subscriptionWrapper
        }

        notificationClosure(subscriptionWrapper.state?.value)

        subscriptionWrapper.addObserver(with: target) { _, newValueWrapper in
            notificationClosure(newValueWrapper?.value)
        }
    }

    func unsubscribeFromAccountVotes(_: AnyObject, accountId: AccountId) {
        guard let subscriptionWrapper = votes[accountId] else {
            return
        }

        subscriptionWrapper.removeObserver(by: self)

        if subscriptionWrapper.observers.isEmpty {
            votes[accountId] = nil
        }
    }
}
