import Foundation

enum MetaAccountOperationFactoryError: Error {
    case unsupportedMethod
    case unsupportedCryptoType(MultiassetCryptoType)
    case derivationPathUnsupported(String)
}
