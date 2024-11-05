import Foundation
import SubstrateSdk
import Operation_iOS

typealias ParaStakingInflationDistrClosure = (Result<ParachainStaking.InflationDistributionPercent?, Error>) -> Void

protocol ParaStakingInflationDistrProviding {
    func setup(with closure: @escaping ParaStakingInflationDistrClosure)
    func throttle()
}

final class ParaStakingInflationDistrProvider: LocalStorageProviderObserving {
    let chainId: ChainModel.Id
    let runtimeService: RuntimeProviderProtocol
    let providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let syncQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var internalProvider: AnyObject?

    init(
        chainId: ChainModel.Id,
        runtimeService: RuntimeProviderProtocol,
        providerFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        syncQueue: DispatchQueue
    ) {
        self.chainId = chainId
        self.runtimeService = runtimeService
        self.providerFactory = providerFactory
        self.operationQueue = operationQueue
        self.syncQueue = syncQueue
    }

    private func subscribeParachainBondConfig(with closure: @escaping ParaStakingInflationDistrClosure) {
        do {
            let provider = try providerFactory.getParachainBondProvider(for: chainId)

            internalProvider = provider

            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            addDataProviderObserver(
                for: provider,
                updateClosure: { item in
                    closure(.success(item?.percent))
                },
                failureClosure: { error in
                    closure(.failure(error))
                },
                callbackQueue: syncQueue,
                options: options
            )
        } catch {
            dispatchInQueueWhenPossible(syncQueue) {
                closure(.failure(error))
            }
        }
    }

    private func subscribeInflationDistribution(
        with closure: @escaping ParaStakingInflationDistrClosure
    ) {
        do {
            let provider = try providerFactory.getInflationDistributionInfoProvider(for: chainId)

            internalProvider = provider

            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            addDataProviderObserver(
                for: provider,
                updateClosure: { records in
                    guard let records, !records.isEmpty else {
                        closure(.success(nil))
                        return
                    }

                    let totalPercent: ParachainStaking.InflationDistributionPercent = records.reduce(
                        0
                    ) { $0 + $1.percent }

                    closure(.success(totalPercent))
                },
                failureClosure: { error in
                    closure(.failure(error))
                },
                callbackQueue: syncQueue,
                options: options
            )
        } catch {
            dispatchInQueueWhenPossible(syncQueue) {
                closure(.failure(error))
            }
        }
    }
}

extension ParaStakingInflationDistrProvider: ParaStakingInflationDistrProviding {
    func setup(with closure: @escaping ParaStakingInflationDistrClosure) {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        execute(
            operation: codingFactoryOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(codingFactory):
                if codingFactory.hasStorage(for: ParachainStaking.inflationDistributionInfoPath) {
                    subscribeInflationDistribution(with: closure)
                } else {
                    subscribeParachainBondConfig(with: closure)
                }
            case let .failure(error):
                closure(.failure(error))
            }
        }
    }

    func throttle() {
        internalProvider = nil
    }
}
