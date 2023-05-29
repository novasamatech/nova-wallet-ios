import Foundation
import IrohaCrypto
import SoraKeystore
import SubstrateSdk

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
    case pinCheckNotPassed
}

final class SigningWrapper: SigningWrapperProtocol, AuthorizationPresentable {
    let keystore: KeystoreProtocol
    let metaId: String
    let accountId: AccountId?
    let isEthereumBased: Bool
    let cryptoType: MultiassetCryptoType
    let publicKeyData: Data
    let settingsManager: SettingsManagerProtocol

    init(
        keystore: KeystoreProtocol,
        metaId: String,
        accountId: AccountId?,
        isEthereumBased: Bool,
        cryptoType: MultiassetCryptoType,
        publicKeyData: Data,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.metaId = metaId
        self.accountId = accountId
        self.cryptoType = cryptoType
        self.isEthereumBased = isEthereumBased
        self.publicKeyData = publicKeyData
        self.settingsManager = settingsManager
    }

    init(
        keystore: KeystoreProtocol,
        metaId: String,
        accountResponse: ChainAccountResponse,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.metaId = metaId
        accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        isEthereumBased = accountResponse.isEthereumBased
        cryptoType = accountResponse.cryptoType
        publicKeyData = accountResponse.publicKey
        self.settingsManager = settingsManager
    }

    init(
        keystore: KeystoreProtocol,
        ethereumAccountResponse: MetaEthereumAccountResponse,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        metaId = ethereumAccountResponse.metaId
        accountId = ethereumAccountResponse.isChainAccount ? ethereumAccountResponse.address : nil
        isEthereumBased = true
        cryptoType = MultiassetCryptoType.ethereumEcdsa
        publicKeyData = ethereumAccountResponse.publicKey
        self.settingsManager = settingsManager
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        if settingsManager.pinConfirmationEnabled == true {
            let signingResult = signAfterAutorization(originalData)
            switch signingResult {
            case let .success(signature):
                return signature
            case let .failure(error):
                throw error
            }
        } else {
            return try _sign(originalData)
        }
    }

    private func signAfterAutorization(_ originalData: Data) -> Result<IRSignatureProtocol, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var signResult: Result<IRSignatureProtocol, Error>?

        DispatchQueue.main.async {
            self.authorize(animated: true, cancellable: true) { [weak self] completed in
                defer {
                    semaphore.signal()
                }
                guard let self = self else {
                    return
                }
                if completed {
                    do {
                        let sign = try self._sign(originalData)
                        signResult = .success(sign)
                    } catch {
                        signResult = .failure(error)
                    }
                }
            }
        }

        semaphore.wait()

        return signResult ?? .failure(SigningWrapperError.pinCheckNotPassed)
    }

    private func _sign(_ originalData: Data) throws -> IRSignatureProtocol {
        let tag: String = isEthereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        switch cryptoType {
        case .sr25519:
            return try signSr25519(originalData, secretKeyData: secretKey, publicKeyData: publicKeyData)
        case .ed25519:
            return try signEd25519(originalData, secretKey: secretKey)
        case .substrateEcdsa:
            return try signEcdsa(originalData, secretKey: secretKey)
        case .ethereumEcdsa:
            return try signEthereum(originalData, secretKey: secretKey)
        }
    }
}
