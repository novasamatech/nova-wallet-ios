import Foundation

struct ParitySignerSigningAccount {
    let rootKeyId: Data?
    let accountResponse: ChainAccountResponse

    var signingIdentity: ParitySignerSigningIdentity {
        if let rootKeyId {
            let model = ParitySignerSigningIdentity.DynamicDerivation(
                rootKeyId: rootKeyId,
                crytoType: accountResponse.cryptoType
            )

            return .dynamicDerivation(model)
        } else {
            let model = ParitySignerSigningIdentity.Regular(
                accountId: accountResponse.accountId,
                cryptoType: accountResponse.cryptoType
            )

            return .regular(model)
        }
    }
}
