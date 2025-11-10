import UIKit
import Operation_iOS
import BigInt

final class EvmGiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?

    let claimDescriptionFactory: EvmClaimableGiftDescriptionFactoryProtocol
    let claimOperationFactory: EvmGiftClaimFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let walletOperationFactory: GiftClaimWalletOperationFactoryProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    let giftInfo: ClaimableGiftInfo
    let totalAmount: BigUInt

    var lastFee: EvmFeeModel?
    var transferType: EvmTransferType?

    init(
        claimDescriptionFactory: EvmClaimableGiftDescriptionFactoryProtocol,
        claimOperationFactory: EvmGiftClaimFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        giftInfo: ClaimableGiftInfo,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        logger: LoggerProtocol,
        operationQueue: OperationQueue,
        totalAmount: BigUInt
    ) {
        self.claimDescriptionFactory = claimDescriptionFactory
        self.claimOperationFactory = claimOperationFactory
        self.chainRegistry = chainRegistry
        self.walletOperationFactory = walletOperationFactory
        self.logger = logger
        self.operationQueue = operationQueue
        self.totalAmount = totalAmount
        self.giftInfo = giftInfo
    }
}

// MARK: - Private

private extension EvmGiftClaimInteractor {
    func setupGift() {
        let walletWrapper = walletOperationFactory.createWrapper()

        let claimGiftDescriptionOperation = claimDescriptionFactory.createDescription(
            for: giftInfo,
            giftAmountWithFee: totalAmount,
            claimingWallet: { try walletWrapper.targetOperation.extractNoCancellableResultData().wallet },
            transferType: .native
        )

        claimGiftDescriptionOperation.addDependency(walletWrapper.targetOperation)

        let resultWrapper = walletWrapper.insertingTail(operation: claimGiftDescriptionOperation)

        execute(
            wrapper: resultWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success((giftDescription, fee)):
                self?.presenter?.didReceive(giftDescription)
                self?.lastFee = fee
            case let .failure(error):
                self?.presenter?.didReceive(error)
                self?.logger.error("Failed on setup: \(error)")
            }
        }
    }

    func setupTransferType() {
        guard
            let chain = chainRegistry.getChain(for: giftInfo.chainId),
            let asset = chain.chainAssetForSymbol(giftInfo.assetSymbol)?.asset
        else {
            return
        }

        if asset.isEvmNative {
            transferType = .native
        } else if let address = asset.evmContractAddress, (try? address.toEthereumAccountId()) != nil {
            transferType = .erc20(address)
        } else {
            presenter?.didReceive(AccountAddressConversionError.invalidEthereumAddress)
        }
    }
}

// MARK: - GiftClaimInteractorInputProtocol

extension EvmGiftClaimInteractor: GiftClaimInteractorInputProtocol {
    func setup() {
        setupTransferType()
        setupGift()
    }

    func claimGift(with giftDescription: ClaimableGiftDescription) {
        guard let lastFee, let transferType else { return }

        let wrapper = claimOperationFactory.createClaimWrapper(
            giftDescription: giftDescription,
            evmFee: lastFee,
            transferType: transferType
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didClaimSuccessfully()
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
}
