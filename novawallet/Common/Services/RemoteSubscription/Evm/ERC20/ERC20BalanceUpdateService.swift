import Foundation
import Operation_iOS
import web3swift
import Core
import SubstrateSdk
import BigInt

typealias ERC20UpdateServiceCompletionClosure = () -> Void

final class ERC20BalanceUpdateService: BaseSyncService, AnyCancellableCleaning {
    let holder: AccountAddress
    let assetContracts: Set<EvmAssetContractId>
    let connection: JSONRPCEngine
    let updateHandler: EvmBalanceUpdateHandling
    let operationQueue: OperationQueue
    let block: EvmBalanceUpdateBlock
    let queryMessageFactory: EvmQueryContractMessageFactoryProtocol
    let completion: ERC20UpdateServiceCompletionClosure?
    let workQueue: DispatchQueue

    private var queryIds: [UInt16]?
    let callStore = CancellableCallStore()

    init(
        holder: AccountAddress,
        assetContracts: Set<EvmAssetContractId>,
        connection: JSONRPCEngine,
        updateHandler: EvmBalanceUpdateHandling,
        operationQueue: OperationQueue,
        block: EvmBalanceUpdateBlock,
        queryMessageFactory: EvmQueryContractMessageFactoryProtocol,
        workQueue: DispatchQueue,
        logger: LoggerProtocol,
        completion: ERC20UpdateServiceCompletionClosure?
    ) {
        self.holder = holder
        self.assetContracts = assetContracts
        self.connection = connection
        self.updateHandler = updateHandler
        self.operationQueue = operationQueue
        self.workQueue = workQueue
        self.block = block
        self.queryMessageFactory = queryMessageFactory
        self.completion = completion

        super.init(logger: logger)
    }

    private func handleAndComplete(balances: [ChainAssetId: BigUInt], holder: AccountAddress) {
        callStore.cancel()

        let wrapper = updateHandler.onBalanceUpdateWrapper(
            balances: balances,
            holder: holder,
            block: block.updateDetectedAt
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case .success:
                self?.completeImmediate(nil)
                self?.completion?()
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    private func extractBalances(
        from responses: [Result<JSON, Error>],
        assetContracts: [EvmAssetContractId]
    ) -> [ChainAssetId: BigUInt] {
        zip(assetContracts, responses).reduce(
            into: [ChainAssetId: BigUInt]()
        ) { accum, contractAndResponse in
            let assetContract = contractAndResponse.0

            switch contractAndResponse.1 {
            case let .success(json):
                if
                    let amountString = json.stringValue,
                    let amount = BigUInt.fromHexString(amountString) {
                    accum[assetContract.chainAssetId] = amount
                } else {
                    logger.error("Unexpected format: \(json)")
                }
            case let .failure(error):
                logger.error("Unexpected error: \(error)")
            }
        }
    }

    private func fetchBalances(
        for holder: AccountAddress,
        assetContracts: Set<EvmAssetContractId>
    ) {
        let batchId = UUID().uuidString

        let assetContractList = Array(assetContracts)

        do {
            for assetContract in assetContractList {
                let call = try queryMessageFactory.erc20Balance(
                    of: holder,
                    contractAddress: assetContract.contract
                )

                let params = EvmQueryMessage.Params(call: call, block: block.fetchRequestedAt)
                try connection.addBatchCallMethod(EvmQueryMessage.method, params: params, batchId: batchId)
            }

            queryIds = try connection.submitBatch(
                for: batchId,
                options: JSONRPCOptions(resendOnReconnect: true)
            ) { [weak self] responses in
                guard let self else {
                    return
                }

                dispatchInQueueWhenPossible(workQueue, locking: mutex) { [weak self] in
                    guard let self else {
                        return
                    }

                    let balances = extractBalances(
                        from: responses,
                        assetContracts: assetContractList
                    )

                    handleAndComplete(balances: balances, holder: holder)
                }
            }
        } catch {
            connection.clearBatch(for: batchId)
            complete(error)
        }
    }

    override func performSyncUp() {
        fetchBalances(for: holder, assetContracts: assetContracts)
    }

    override func stopSyncUp() {
        if let queryIds = queryIds {
            connection.cancelForIdentifiers(queryIds)
        }

        callStore.cancel()
    }
}
