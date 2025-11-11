import Foundation
import Operation_iOS

enum GiftedWalletType {
    case available(SubType)
    case unavailable(SubType)

    var wallet: MetaAccountModel {
        switch self {
        case let .available(type), let .unavailable(type):
            type.wallet
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

protocol GiftClaimWalletOperationFactoryProtocol {
    func createWrapper(selectedWallet: MetaAccountModel?) -> CompoundOperationWrapper<GiftedWalletType>
}

final class GiftClaimWalletOperationFactory {
    private let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>

    init(walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>) {
        self.walletRepository = walletRepository
    }
}

// MARK: - Private

private extension GiftClaimWalletOperationFactory {
    func determineRecipientWallet(
        in wallets: [ManagedMetaAccountModel],
        selectedWallet: MetaAccountModel?
    ) throws -> GiftedWalletType {
        let eligibleWallletTypes: Set<MetaAccountModelType> = [
            .secrets,
            .ledger,
            .genericLedger,
            .paritySigner,
            .polkadotVault
        ]

        let eligibleWallets = wallets
            .filter { eligibleWallletTypes.contains($0.info.type) }

        let selectedWallet = selectedWallet ?? wallets.first { $0.isSelected }?.info

        guard let selectedWallet else { throw GiftClaimWalletOperationFactoryError.selectedWalletNotFound }

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
}

// MARK: - GiftClaimWalletOperationFactoryProtocol

extension GiftClaimWalletOperationFactory: GiftClaimWalletOperationFactoryProtocol {
    func createWrapper(selectedWallet: MetaAccountModel?) -> CompoundOperationWrapper<GiftedWalletType> {
        let walletsFetchOperation = walletRepository.fetchAllOperation(with: .init())

        let resultOperation = ClosureOperation<GiftedWalletType> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let wallets = try walletsFetchOperation.extractNoCancellableResultData()

            return try determineRecipientWallet(
                in: wallets,
                selectedWallet: selectedWallet
            )
        }

        resultOperation.addDependency(walletsFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [walletsFetchOperation]
        )
    }
}

// MARK: - Errors

enum GiftClaimWalletOperationFactoryError: Error {
    case selectedWalletNotFound
}
