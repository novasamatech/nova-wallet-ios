import Foundation

struct ParitySignerTxQrSetupModel {
    let chainWallet: ChainWalletDisplayAddress
    let verificationModel: ParitySignerSignatureVerificationModel
    let preferredFormats: ParitySignerPreferredQRFormats
    let txExpirationTime: TimeInterval?
}
