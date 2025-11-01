import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

class GiftTransferInteractor: GiftTransferBaseInteractor {
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let transferCommandFactory: SubstrateTransferCommandFactory
    let extrinsicService: ExtrinsicServiceProtocol
    let transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol

    var setupPresenter: GiftTransferSetupInteractorOutputProtocol? {
        presenter as? GiftTransferSetupInteractorOutputProtocol
    }

    private lazy var assetStorageInfoFactory = AssetStorageInfoOperationFactory()

    private var setupCall: CancellableCall?

    private var sendingAssetInfo: AssetStorageInfo?

    private(set) var feeAsset: ChainAsset?

    private let assetStorageCallStore = CancellableCallStore()

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeAsset: ChainAsset?,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        transferCommandFactory: SubstrateTransferCommandFactory,
        extrinsicService: ExtrinsicServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.feeAsset = feeAsset
        self.transferCommandFactory = transferCommandFactory
        self.extrinsicService = extrinsicService
        self.transferAggregationWrapperFactory = transferAggregationWrapperFactory

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationQueue: operationQueue
        )

        self.currencyManager = currencyManager
    }

    override func estimateFee(
        for amount: OnChainTransferAmount<BigUInt>,
        transactionId: GiftTransferBaseInteractor.GiftTransactionFeeId,
        recepientAccountId: AccountId
    ) {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: transactionId.rawValue,
            payingIn: feeAsset?.chainAssetId
        ) { [weak self] builder in
            let (newBuilder, _) = try self?.addingTransferCommand(
                to: builder,
                amount: amount,
                recepient: recepientAccountId
            ) ?? (builder, nil)

            return newBuilder
        }
    }

    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let sendingAssetInfo = sendingAssetInfo else {
            return (builder, nil)
        }

        return try transferCommandFactory.addingTransferCommand(
            to: builder,
            amount: amount,
            recipient: recepient,
            assetStorageInfo: sendingAssetInfo
        )
    }
}

// MARK: - Private

private extension GiftTransferInteractor {
    func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupSendingAssetPriceProviderIfNeeded()

        provideMinBalance()

        setupPresenter?.didCompleteSetup()
    }

    func provideMinBalance() {
        guard let sendingAssetInfo else { return }

        let wrapper = assetStorageInfoFactory.createAssetBalanceExistenceOperation(
            for: sendingAssetInfo,
            chainId: chain.chainId,
            asset: asset
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(existence):
                self?.setupPresenter?.didReceiveSendingAssetExistence(existence)
            case let .failure(error):
                self?.setupPresenter?.didReceiveError(error)
            }
        }
    }

    func processClaimFee(
        transactionFeeId: String,
        fee: ExtrinsicFeeProtocol,
        giftFeeDescriptionBuilder: GiftFeeDescriptionBuilder
    ) {
        guard let giftTransactionFeeId = GiftTransactionFeeId(rawValue: transactionFeeId) else { return }

        let amount = giftTransactionFeeId.amount.map { $0 + fee.amount }
        let newBuilder = giftFeeDescriptionBuilder.with(claimFee: fee)
        estimateFee(for: amount, feeType: .createGift(newBuilder))
    }

    func processCreateFee(
        fee: ExtrinsicFeeProtocol,
        giftFeeDescriptionBuilder: GiftFeeDescriptionBuilder
    ) {
        guard let giftFeeDescription = giftFeeDescriptionBuilder
            .with(createFee: fee)
            .build()
        else { return }

        do {
            let totalFee = try giftFeeDescription.createAccumulatedFee()
            let feeModel = FeeOutputModel(value: totalFee, validationProvider: nil)
            setupPresenter?.didReceiveFee(result: .success(feeModel))
            setupPresenter?.didReceiveFee(description: giftFeeDescription)
        } catch {
            logger.error("Error calculating accumulated fee: \(error)")
        }
    }
}

// MARK: - Internal

extension GiftTransferInteractor {
    func setup() {
        let assetStorageWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeService
        )

        executeCancellable(
            wrapper: assetStorageWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: assetStorageCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.sendingAssetInfo = info

                self?.continueSetup()
            case let .failure(error):
                self?.setupPresenter?.didReceiveError(error)
            }
        }
    }
}

// MARK: - ExtrinsicFeeProxyDelegate

extension GiftTransferInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for transactionFeeId: TransactionFeeId
    ) {
        guard let feeType = pendingFees[transactionFeeId] else { return }

        pendingFees[transactionFeeId] = nil

        switch (result, feeType) {
        case let (.success(fee), .claimGift(builder)):
            processClaimFee(
                transactionFeeId: transactionFeeId,
                fee: fee,
                giftFeeDescriptionBuilder: builder
            )
        case let (.success(fee), .createGift(builder)):
            processCreateFee(
                fee: fee,
                giftFeeDescriptionBuilder: builder
            )
        case let (.failure(error), _):
            setupPresenter?.didReceiveFee(result: .failure(error))
        }
    }
}
