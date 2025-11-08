import UIKit
import Operation_iOS
import BigInt

final class GiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let giftInfo: ClaimableGiftInfo
    let totalAmount: BigUInt
    let feeProxy: ExtrinsicFeeProxyProtocol
    let transferCommandFactory: SubstrateTransferCommandFactory
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let logger: LoggerProtocol
    let operationQueue: OperationQueue
    
    var assetStorageInfo: AssetStorageInfo?
    var walletToGift: MetaAccountModel?
}

// MARK: - Private

private extension GiftClaimInteractor {
    func getChainAsset() -> ChainAsset? {
        guard let chain = chainRegistry.getChain(for: giftInfo.chainId) else {
            return nil
        }
        
        return chain.chainAssetForSymbol(giftInfo.assetSymbol)
    }
    
    func calculateFee() {
        guard let chainAsset = getChainAsset() else { return }
        
        let accountId = chainAsset.chain.emptyAccountId()
        
        let amount = .all(value: totalAmount)
        
        let transactionId = GiftTransactionFeeId(
            recepientAccountId: accountId,
            amount: amount
        )
        
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: transactionId,
            payingIn: chainAsset.chainAssetId
        ) { [weak self] builder in
            let (newBuilder, _) = try self?.addingTransferCommand(
                to: builder,
                amount: amount,
                recepient: accountId
            ) ?? (builder, nil)

            return newBuilder
        }
    }
    
    func determineRecipientWallet(in wallets: [ManagedMetaAccountModel]) -> GiftedWalletType? {
        let eligibleWallletTypes: Set<MetaAccountModelType> = [
            .secrets,
            .ledger,
            .genericLedger
        ]
        
        let eligibleWallets = wallets
            .filter { eligibleWallletTypes.contains($0.info.type) }
        
        let selectedWallet = wallets.first { $0.isSelected }?.info
        
        guard let selectedWallet else { return nil }
        
        if eligibleWallletTypes.contains(selectedWallet.type) {
            let giftedWalletType: GiftedWalletType = eligibleWallets.count > 1
                ? .available(.oneInSet(selectedWallet))
                : .available(.single(selectedWallet))
            
            return giftedWalletType
        } else {
            guard let giftedWallet = eligibleWallets.first?.info else {
                return .unavailable(.single(selectedWallet))
            }
            
            let giftedWalletType: GiftedWalletType = eligibleWallets.count > 1
                ? .available(.oneInSet(giftedWallet))
                : .available(.single(giftedWallet))
            
            return giftedWalletType
        }
    }
    
    func setupWalletToGift() {
        let walletsOperation = walletRepository.fetchAllOperation(with: .init())
        
        execute(
            operation: walletsOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case let .success(wallets):
                guard let recepientWalletType = determineRecipientWallet(in: wallets) else { return }
                
                walletToGift = recepientWalletType.wallet
            case let .failure(error):
                presenter?.didReceive(error)
                logger.error("Failed fetching local wallets: \(error)")
            }
        }
    }
    
    func setupAssetInfo() {
        guard
            let chainAsset = getChainAsset(),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else { return }
        
        let assetStorageWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: chainAsset.asset,
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
                self?.assetStorageInfo = info

                self?.continueSetup()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
    
    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let assetStorageInfo else {
            return (builder, nil)
        }

        return try transferCommandFactory.addingTransferCommand(
            to: builder,
            amount: amount,
            recipient: recepient,
            assetStorageInfo: assetStorageInfo
        )
    }
    
    func continuSetup() {
        
    }
}

// MARK: - GiftClaimInteractorInputProtocol

extension GiftClaimInteractor: GiftClaimInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
        
        setupAssetInfo()
    }
}

// MARK: - ExtrinsicFeeProxyDelegate

extension GiftClaimInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<any ExtrinsicFeeProtocol, any Error>,
        for identifier: TransactionFeeId
    ) {
        <#code#>
    }
}

enum GiftedWalletType {
    case available(SubType)
    case unavailable(SubType)
    
    var wallet: MetaAccountModel {
        switch self {
        case let .available(type), let .unavailable(type):
            return type.wallet
        }
    }
}

extension GiftedWalletType {
    enum SubType {
        case single(MetaAccountModel)
        case oneInSet(MetaAccountModel)
        
        var wallet: MetaAccountModel {
            switch self {
            case let .single(wallet), let .oneInSet(wallet):
                return wallet
            }
        }
    }
}

struct ClaimableGiftDescription {
    let amount: BigUInt
    let chainAsset: ChainAsset
    let claimingAccountId: AccountId
}
