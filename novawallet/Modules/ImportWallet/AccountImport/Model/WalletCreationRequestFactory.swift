import Foundation
import NovaCrypto

struct WalletWithMnemonicCreationRequest {
    let mnemonic: IRMnemonicProtocol
    let walletRequest: MetaAccountCreationRequest
}

protocol WalletCreationRequestFactoryProtocol {
    func createNewWalletRequest(for walletName: String) throws -> WalletWithMnemonicCreationRequest
    func createAccountRequest(for chain: ChainModel) throws -> ChainAccountImportMnemonicRequest
    func generateMnemonic() throws -> IRMnemonicProtocol
}

final class WalletCreationRequestFactory {
    private lazy var mnemonicCreator = IRMnemonicCreator()
}

extension WalletCreationRequestFactory: WalletCreationRequestFactoryProtocol {
    func generateMnemonic() throws -> IRMnemonicProtocol {
        try mnemonicCreator.randomMnemonic(.entropy128)
    }

    func createNewWalletRequest(for walletName: String) throws -> WalletWithMnemonicCreationRequest {
        let mnemonic = try generateMnemonic()
        let walletRequest = MetaAccountCreationRequest(
            username: walletName,
            derivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519
        )

        return WalletWithMnemonicCreationRequest(mnemonic: mnemonic, walletRequest: walletRequest)
    }

    func createAccountRequest(for chain: ChainModel) throws -> ChainAccountImportMnemonicRequest {
        let mnemonic = try generateMnemonic()

        if chain.isEthereumBased {
            return ChainAccountImportMnemonicRequest(
                mnemonic: mnemonic.toString(),
                derivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .ethereumEcdsa
            )
        } else {
            return ChainAccountImportMnemonicRequest(
                mnemonic: mnemonic.toString(),
                derivationPath: "",
                cryptoType: .sr25519
            )
        }
    }
}
