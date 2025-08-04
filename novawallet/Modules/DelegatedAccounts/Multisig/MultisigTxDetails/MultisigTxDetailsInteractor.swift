import UIKit
import SubstrateSdk
import Operation_iOS
import BigInt

final class MultisigTxDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MultisigTxDetailsInteractorOutputProtocol?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    let pendingOperation: Multisig.PendingOperationProxyModel

    let chain: ChainModel
    let chainRegistry: ChainRegistryProtocol
    let prettyPrintedJSONOperationFactory: PrettyPrintedJSONOperationFactoryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var priceProvider: StreamableProvider<PriceData>?

    init(
        pendingOperation: Multisig.PendingOperationProxyModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        prettyPrintedJSONOperationFactory: PrettyPrintedJSONOperationFactoryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.pendingOperation = pendingOperation
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.prettyPrintedJSONOperationFactory = prettyPrintedJSONOperationFactory
        self.walletRepository = walletRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }
}

// MARK: Private

private extension MultisigTxDetailsInteractor {
    func setupChainAssetPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard
            let asset = chain.utilityAsset(),
            let priceId = asset.priceId
        else {
            return
        }

        priceProvider = subscribeToPrice(
            for: priceId,
            currency: selectedCurrency
        )
    }

    func provideTxDetails() {
        let wrapper = createTxDetailsWrapper(for: chain)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(txDetails):
                self?.presenter?.didReceive(txDetails: txDetails)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func provideCallDisplayString() {
        guard
            let callJson = pendingOperation.formattedModel?.decoded.toDisplayRepresentation()
        else {
            return
        }

        let prettifyOperation = prettyPrintedJSONOperationFactory.createProcessingOperation(
            for: callJson
        )

        execute(
            operation: prettifyOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case let .success(displayString):
                self?.presenter?.didReceive(prettifiedCallString: displayString)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func createTxDetailsWrapper(for chain: ChainModel) -> CompoundOperationWrapper<MultisigTxDetails> {
        let localAccountsWrapper = walletRepository.createWalletsWrapperByAccountId(
            for: chain
        )

        let mapOperation: BaseOperation<MultisigTxDetails> = ClosureOperation { [weak self] in
            guard
                let self,
                let definition = pendingOperation.operation.multisigDefinition
            else { throw BaseOperationError.parentOperationCancelled }

            let localAccounts = try localAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let depositor: MultisigTxDetails.Account

            if let localDepositor = localAccounts[definition.depositor] {
                depositor = .local(localDepositor)
            } else {
                depositor = .remote(definition.depositor)
            }

            return MultisigTxDetails(
                depositAmount: definition.deposit,
                depositor: depositor,
                callHash: pendingOperation.operation.callHash,
                callData: pendingOperation.operation.call
            )
        }

        mapOperation.addDependency(localAccountsWrapper.targetOperation)

        return localAccountsWrapper.insertingTail(operation: mapOperation)
    }
}

// MARK: - MultisigTxDetailsInteractorInputProtocol

extension MultisigTxDetailsInteractor: MultisigTxDetailsInteractorInputProtocol {
    func setup() {
        provideTxDetails()
        provideCallDisplayString()
    }
}

// MARK: - PriceLocalSubscriptionHandler

extension MultisigTxDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, any Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(priceData: priceData)
        case let .failure(error):
            logger.error("Can't load local price: \(error)")
            presenter?.didReceive(priceData: nil)
        }
    }
}

// MARK: - SelectedCurrencyDepending

extension MultisigTxDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupChainAssetPriceSubscription()
    }
}
