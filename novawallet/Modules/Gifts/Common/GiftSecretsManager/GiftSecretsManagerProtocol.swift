import Foundation
import Operation_iOS

protocol GiftSecretsManagerProtocol: GiftSecretsCleaningProtocol,
    GiftSecretsProvidingProtocol,
    GiftPublicKeyProvidingProtocol
{
    func createSecrets(request: GiftSecretCreationRequest) -> BaseOperation<AccountId>
}

protocol GiftSecretsCleaningProtocol {
    func cleanSecrets(for info: GiftSecretKeyInfo) -> BaseOperation<Void>
}

protocol GiftSecretsProvidingProtocol {
    func getSecrets(for info: GiftSecretKeyInfo) -> BaseOperation<GiftSecrets>
    func getSecrets(for info: GiftSecretKeyInfo) throws -> GiftSecrets
}

protocol GiftPublicKeyProvidingProtocol {
    func getPublicKey(request: GiftPublicKeyFetchRequest) -> BaseOperation<Data>
    func getPublicKey(request: GiftPublicKeyFetchRequest) throws -> Data
}
