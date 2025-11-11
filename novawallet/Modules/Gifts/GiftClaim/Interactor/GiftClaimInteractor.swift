import UIKit
import Operation_iOS
import BigInt

class GiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let walletOperationFactory: GiftClaimWalletOperationFactoryProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    let claimableGift: ClaimableGiftInfo
    let totalAmount: BigUInt

    var walletListSubscription: StreamableProvider<ManagedMetaAccountModel>?
    var giftedWallet: GiftedWalletType?

    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        claimableGift: ClaimableGiftInfo,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol,
        totalAmount: BigUInt,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.walletOperationFactory = walletOperationFactory
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.logger = logger
        self.claimableGift = claimableGift
        self.totalAmount = totalAmount
        self.operationQueue = operationQueue
    }

    func performSetup(with _: MetaAccountModel?) {
        fatalError("Must be overriden by a subclass")
    }

    func claimGift(giftDescription _: ClaimableGiftDescription) {
        fatalError("Must be overriden by a subclass")
    }
}

extension GiftClaimInteractor {
    func setupSelectedWalletSubscription() {
        walletListSubscription = subscribeSelectedWalletProvider()
    }
}

extension GiftClaimInteractor: GiftClaimInteractorInputProtocol {
    func setup() {
        setupSelectedWalletSubscription()
        performSetup(with: nil)
    }

    func claimGift(with giftDescription: ClaimableGiftDescription) {
        claimGift(giftDescription: giftDescription)
    }

    func changeWallet(to wallet: MetaAccountModel) {
        performSetup(with: wallet)
    }
}

extension GiftClaimInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleSelectedWallet(result: Result<ManagedMetaAccountModel?, any Error>) {
        switch result {
        case let .success(managedMetaAccount):
            guard giftedWallet != nil else { return }

            performSetup(with: managedMetaAccount?.info)
        case let .failure(error):
            logger.error("Failed on wallet subscription: \(error)")
        }
    }
}

extension GiftClaimInteractor {
    struct ClaimSetupResult {
        let giftedWallet: GiftedWalletType
        let giftDescription: ClaimableGiftDescription
    }
}
