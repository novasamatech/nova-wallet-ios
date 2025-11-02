import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt
import NovaCrypto
import Keystore_iOS

// Facade factory that will be extended with remote gift factory later

protocol GiftOperationFactoryProtocol {
    func createGiftOperation(
        amount: OnChainTransferAmount<BigUInt>,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel>

    func cleanSecrets(
        for localGiftAccountId: AccountId,
        chainAsset: ChainAsset
    ) -> BaseOperation<Void>
}

final class GiftOperationFactory {
    private let localGiftFactory: GiftLocalFactoryProtocol

    init(localGiftFactory: GiftLocalFactoryProtocol) {
        self.localGiftFactory = localGiftFactory
    }
}

// MARK: - GiftOperationFactoryProtocol

extension GiftOperationFactory: GiftOperationFactoryProtocol {
    func createGiftOperation(
        amount: OnChainTransferAmount<BigUInt>,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel> {
        localGiftFactory.createGiftOperation(
            amount: amount.value,
            chainAsset: chainAsset
        )
    }

    func cleanSecrets(
        for localGiftAccountId: AccountId,
        chainAsset: ChainAsset
    ) -> BaseOperation<Void> {
        localGiftFactory.cleanSecrets(
            for: localGiftAccountId,
            ethereumBased: chainAsset.chain.isEthereumBased
        )
    }
}
