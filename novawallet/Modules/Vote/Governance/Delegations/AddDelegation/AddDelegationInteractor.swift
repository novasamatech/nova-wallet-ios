import UIKit
import SubstrateSdk
import RobinHood
import SoraKeystore

final class AddDelegationInteractor {
    weak var presenter: AddDelegationInteractorOutputProtocol?

    let chain: ChainModel
    let lastVotedDays: Int
    let fetchBlockTreshold: BlockNumber
    let delegateListOperationFactory: GovernanceDelegateListFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    private(set) var settings: SettingsManagerProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var lastUsedBlockNumber: BlockNumber?
    private var currentBlockNumber: BlockNumber?
    private var currentBlockTime: BlockTime?

    init(
        chain: ChainModel,
        lastVotedDays: Int,
        fetchBlockTreshold: BlockNumber,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        delegateListOperationFactory: GovernanceDelegateListFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.fetchBlockTreshold = fetchBlockTreshold
        self.connection = connection
        self.runtimeService = runtimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.delegateListOperationFactory = delegateListOperationFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.settings = settings
        self.operationQueue = operationQueue
    }

    private func updateBlockTime() {
        let blockTimeUpdateWrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeUpdateWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let blockTime = try blockTimeUpdateWrapper.targetOperation.extractNoCancellableResultData()
                    self?.currentBlockTime = blockTime

                    self?.fetchDelegateListIfNeeded()
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(blockTimeUpdateWrapper.allOperations, waitUntilFinished: false)
    }

    private func estimateStatsBlockNumber() -> BlockNumber? {
        guard let blockNumber = currentBlockNumber, let blockTime = currentBlockTime, blockTime > 0 else {
            return nil
        }

        let blocksInPast = BlockNumber(TimeInterval(lastVotedDays).secondsFromDays / TimeInterval(blockTime).seconds)

        guard blockNumber > blocksInPast else {
            return nil
        }

        return blockNumber - blocksInPast
    }

    private func fetchDelegateListIfNeeded() {
        guard let activityBlockNumber = estimateStatsBlockNumber() else {
            return
        }

        if
            let lastUsedBlockNumber = lastUsedBlockNumber,
            activityBlockNumber > lastUsedBlockNumber,
            activityBlockNumber - lastUsedBlockNumber < fetchBlockTreshold {
            return
        }

        lastUsedBlockNumber = activityBlockNumber

        let wrapper = delegateListOperationFactory.fetchDelegateListWrapper(
            for: activityBlockNumber,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let delegates = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveDelegates(delegates)
                } catch {
                    self?.presenter?.didReceiveError(.delegateListFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func subscribeBlockNumber() {
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    private func provideSettings() {
        presenter?.didReceiveShouldDisplayBanner(settings.governanceDelegateInfoSeen)
    }
}

extension AddDelegationInteractor: AddDelegationInteractorInputProtocol {
    func setup() {
        subscribeBlockNumber()
        provideSettings()
    }

    func remakeSubscriptions() {
        subscribeBlockNumber()
    }

    func refreshDelegates() {
        lastUsedBlockNumber = nil

        fetchDelegateListIfNeeded()
    }

    func saveCloseBanner() {
        settings.governanceDelegateInfoSeen = true
    }
}

extension AddDelegationInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                currentBlockNumber = blockNumber

                updateBlockTime()
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
    }
}
