import UIKit
import Operation_iOS
import BigInt

class GiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let walletOperationFactory: GiftClaimWalletOperationFactoryProtocol
    let logger: LoggerProtocol

    let giftInfo: ClaimableGiftInfo
    let totalAmount: BigUInt

    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        giftInfo: ClaimableGiftInfo,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        logger: LoggerProtocol,
        totalAmount: BigUInt,
        operationQueue: OperationQueue,
    ) {
        self.chainRegistry = chainRegistry
        self.walletOperationFactory = walletOperationFactory
        self.logger = logger
        self.giftInfo = giftInfo
        self.totalAmount = totalAmount
        self.operationQueue = operationQueue
    }

    func performSetup() {
        fatalError("Must be overriden by a subclass")
    }

    func claimGift(giftDescription _: ClaimableGiftDescription) {
        fatalError("Must be overriden by a subclass")
    }
}

extension GiftClaimInteractor: GiftClaimInteractorInputProtocol {
    func setup() {
        performSetup()
    }

    func claimGift(with giftDescription: ClaimableGiftDescription) {
        claimGift(giftDescription: giftDescription)
    }
}
