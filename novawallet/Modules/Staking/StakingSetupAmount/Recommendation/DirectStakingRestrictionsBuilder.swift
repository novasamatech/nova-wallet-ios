import Foundation
import Operation_iOS
import BigInt

final class DirectStakingRestrictionsBuilder: AnyCancellableCleaning {
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let networkInfoFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    private var minJoinStakeStorage: UncertainStorage<BigUInt?> = .undefined
    private var minRewardableStakeStorage: UncertainStorage<BigUInt?> = .undefined
    private var counterForNominatorsStorage: UncertainStorage<UInt32?> = .undefined
    private var maxNominatorCountStorage: UncertainStorage<UInt32?> = .undefined

    private var bagListProvider: AnyDataProvider<DecodedU32>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    private var networkInfoCancellable: CancellableCall?

    private var minRewardableStakeBuilder: DirectStakingMinStakeBuilder?

    weak var delegate: RelaychainStakingRestrictionsBuilderDelegate?

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        networkInfoFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.networkInfoFactory = networkInfoFactory
        self.eraValidatorService = eraValidatorService
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }

    deinit {
        clear(cancellable: &networkInfoCancellable)
    }

    private func provideNetworkInfo() {
        let wrapper = networkInfoFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.networkInfoCancellable === wrapper else {
                    return
                }

                self.networkInfoCancellable = nil

                do {
                    let networkInfo = try wrapper.targetOperation.extractNoCancellableResultData()
                    self.minRewardableStakeBuilder?.apply(param1: networkInfo)
                } catch {
                    self.delegate?.restrictionsBuilder(self, didReceive: error)
                }
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func sendUpdateIfReady() {
        guard
            minJoinStakeStorage.isDefined,
            minRewardableStakeStorage.isDefined,
            counterForNominatorsStorage.isDefined,
            maxNominatorCountStorage.isDefined else {
            return
        }

        let allowsNewStakers: Bool

        if
            let counterForNominators = counterForNominatorsStorage.valueWhenDefined(else: nil),
            let maxNominatorsCount = maxNominatorCountStorage.valueWhenDefined(else: nil) {
            allowsNewStakers = counterForNominators < maxNominatorsCount
        } else {
            allowsNewStakers = true
        }

        let restrictions = RelaychainStakingRestrictions(
            minJoinStake: minJoinStakeStorage.valueWhenDefined(else: nil),
            minRewardableStake: minRewardableStakeStorage.valueWhenDefined(else: nil),
            allowsNewStakers: allowsNewStakers
        )

        delegate?.restrictionsBuilder(self, didPrepare: restrictions)
    }
}

extension DirectStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding {
    func start() {
        minRewardableStakeBuilder = DirectStakingMinStakeBuilder { [weak self] value in
            self?.minRewardableStakeStorage = .defined(value)
            self?.sendUpdateIfReady()
        }

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)
        bagListProvider = subscribeBagsListSize(for: chainAsset.chain.chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)

        provideNetworkInfo()
    }

    func stop() {
        clear(cancellable: &networkInfoCancellable)

        minBondProvider = nil
        bagListProvider = nil
        maxNominatorsCountProvider = nil
        counterForNominatorsProvider = nil
        minRewardableStakeBuilder = nil

        minJoinStakeStorage = .undefined
        minRewardableStakeStorage = .undefined
        counterForNominatorsStorage = .undefined
        maxNominatorCountStorage = .undefined
    }
}

extension DirectStakingRestrictionsBuilder: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(minNominatorBond):
            minJoinStakeStorage = .defined(minNominatorBond)
            minRewardableStakeBuilder?.apply(param3: minNominatorBond)
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(bagListSize):
            minRewardableStakeBuilder?.apply(param2: bagListSize)
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(counterForNominators):
            counterForNominatorsStorage = .defined(counterForNominators)
            sendUpdateIfReady()
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(maxNominatorCount):
            maxNominatorCountStorage = .defined(maxNominatorCount)
            sendUpdateIfReady()
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }
}
