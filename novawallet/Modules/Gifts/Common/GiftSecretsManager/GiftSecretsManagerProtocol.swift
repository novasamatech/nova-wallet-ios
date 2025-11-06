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
    func getSecrets(for info: GiftSecretKeyInfo) -> BaseOperation<GiftSecrets?>
}

protocol GiftPublicKeyProvidingProtocol {
    func getPublicKey(request: GiftPublicKeyFetchRequest) -> BaseOperation<AccountId>
}
