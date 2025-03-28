import Foundation

struct ParitySignerTxQrSetupModel {
    let chainWallet: ChainWalletDisplayAddress
    let preferredFormats: ParitySignerPreferredQRFormats
    let txExpirationTime: TimeInterval?
}
