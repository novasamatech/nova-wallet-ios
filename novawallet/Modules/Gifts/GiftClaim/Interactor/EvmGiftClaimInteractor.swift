import UIKit
import Operation_iOS
import BigInt

final class EvmGiftClaimInteractor: GiftClaimInteractor {
    let claimDescriptionFactory: EvmClaimableGiftDescriptionFactoryProtocol
    let claimOperationFactory: EvmGiftClaimFactoryProtocol

    var lastFee: EvmFeeModel?
    var transferType: EvmTransferType?

    init(
        claimDescriptionFactory: EvmClaimableGiftDescriptionFactoryProtocol,
        claimOperationFactory: EvmGiftClaimFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        claimableGift: ClaimableGiftInfo,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        logger: LoggerProtocol,
        totalAmount: BigUInt,
        operationQueue: OperationQueue
    ) {
        self.claimDescriptionFactory = claimDescriptionFactory
        self.claimOperationFactory = claimOperationFactory

        super.init(
            chainRegistry: chainRegistry,
            claimableGift: claimableGift,
            walletOperationFactory: walletOperationFactory,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }

    // MARK: - Override

    override func performSetup() {
        setupTransferType()
        setupGift()
    }

    override func claimGift(giftDescription: ClaimableGiftDescription) {
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

// MARK: - Private

private extension EvmGiftClaimInteractor {
    func setupGift() {
        let walletWrapper = walletOperationFactory.createWrapper()

        let claimGiftDescriptionOperation = claimDescriptionFactory.createDescription(
            for: claimableGift,
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
        let asset = claimableGift.chainAsset.asset

        if asset.isEvmNative {
            transferType = .native
        } else if let address = asset.evmContractAddress, (try? address.toEthereumAccountId()) != nil {
            transferType = .erc20(address)
        } else {
            presenter?.didReceive(AccountAddressConversionError.invalidEthereumAddress)
        }
    }
}
