import UIKit
import Operation_iOS
import BigInt

class GiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let walletOperationFactory: GiftClaimWalletOperationFactoryProtocol
    let logger: LoggerProtocol

    let claimableGift: ClaimableGiftInfo
    let totalAmount: BigUInt

    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        claimableGift: ClaimableGiftInfo,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        logger: LoggerProtocol,
        totalAmount: BigUInt,
        operationQueue: OperationQueue,
    ) {
        self.chainRegistry = chainRegistry
        self.walletOperationFactory = walletOperationFactory
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

extension GiftClaimInteractor: GiftClaimInteractorInputProtocol {
    func setup() {
        performSetup(with: nil)
    }

    func claimGift(with giftDescription: ClaimableGiftDescription) {
        claimGift(giftDescription: giftDescription)
    }

    func changeWallet(to wallet: MetaAccountModel) {
        performSetup(with: wallet)
    }
}

extension GiftClaimInteractor {
    struct ClaimSetupResult {
        let giftedWallet: GiftedWalletType
        let giftDescription: ClaimableGiftDescription
    }
}
