import Foundation
import SubstrateSdk
import RobinHood

extension Gov2SubscriptionFactory {
    func handleReferendumResult(
        _ result: Result<CallbackStorageSubscriptionResult<ReferendumInfo>, Error>,
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

    func handleReferendum(
        for referendumInfo: ReferendumInfo,
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
}
