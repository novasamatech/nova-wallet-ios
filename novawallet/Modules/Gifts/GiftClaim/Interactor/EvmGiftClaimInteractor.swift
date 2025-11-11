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

    override func performSetup(with wallet: MetaAccountModel?) {
        setupTransferType()
        setupGift(selectedWallet: wallet)
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
    func setupGift(selectedWallet: MetaAccountModel?) {
        guard let transferType else { return }

        let wrapper = createSetupWrapper(
            for: transferType,
            selectedWallet: selectedWallet
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(setupResult):
                self?.presenter?.didReceive(setupResult.claimSetupResult)
                self?.lastFee = setupResult.fee
            case let .failure(error):
                self?.presenter?.didReceive(error)
                self?.logger.error("Failed on setup: \(error)")
            }
        }
    }

    func createSetupWrapper(
        for transferType: EvmTransferType,
        selectedWallet: MetaAccountModel?
    ) -> CompoundOperationWrapper<GiftClaimSetupResult> {
        let walletWrapper = walletOperationFactory.createWrapper(selectedWallet: selectedWallet)

        let claimGiftDescriptionOperation = claimDescriptionFactory.createDescription(
            for: claimableGift,
            giftAmountWithFee: totalAmount,
            claimingWallet: { try walletWrapper.targetOperation.extractNoCancellableResultData().wallet },
            transferType: transferType
        )

        claimGiftDescriptionOperation.addDependency(walletWrapper.targetOperation)

        let resultOperation = ClosureOperation {
            let giftedWallet = try walletWrapper.targetOperation.extractNoCancellableResultData()
            let giftDescriptionAndFee = try claimGiftDescriptionOperation.extractNoCancellableResultData()

            return GiftClaimSetupResult(
                claimSetupResult: .init(
                    giftedWallet: giftedWallet,
                    giftDescription: giftDescriptionAndFee.0
                ),
                fee: giftDescriptionAndFee.1
            )
        }

        resultOperation.addDependency(claimGiftDescriptionOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [claimGiftDescriptionOperation] + walletWrapper.allOperations
        )
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

private extension EvmGiftClaimInteractor {
    struct GiftClaimSetupResult {
        let claimSetupResult: GiftClaimInteractor.ClaimSetupResult
        let fee: EvmFeeModel
    }
}
