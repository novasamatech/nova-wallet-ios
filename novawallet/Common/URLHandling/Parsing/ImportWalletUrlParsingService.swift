import Foundation
import Operation_iOS
import IrohaCrypto
import Foundation_iOS

enum CreateWalletError: Error, ErrorContentConvertible {
    case emptyMnemonic
    case invalidMnemonic
    case invalidCryptoType
    case invalidSubstrateDerivationPath
    case invalidEvmDerivationPath
    case emptyQueryParameters

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let locale = locale ?? .current
        let message: String
        switch self {
        case .emptyMnemonic, .invalidMnemonic, .emptyQueryParameters:
            message = R.string.localizable.deeplinkErrorInvalidMnemonicMessage(
                preferredLanguages: locale.rLanguages
            )
        case .invalidCryptoType:
            message = R.string.localizable.deeplinkErrorInvalidCryptoTypeMessage(
                preferredLanguages: locale.rLanguages
            )
        case .invalidSubstrateDerivationPath, .invalidEvmDerivationPath:
            message = R.string.localizable.deeplinkErrorInvalidDerivationPathMessage(
                preferredLanguages: locale.rLanguages
            )
        }

        return .init(title: "", message: message)
    }
}

final class ImportWalletUrlParsingService {
    enum Key {
        static let mnemonic = "mnemonic"
        static let type = "cryptotype"
        static let substrateDeriviationPath = "substratedp"
        static let evmDeriviationPath = "evmdp"
    }

    func parse(url: URL) -> Result<MnemonicDefinition, CreateWalletError> {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            return .failure(.emptyQueryParameters)
        }

        let queryItems = query.reduce(into: [String: String]()) {
            $0[$1.name.lowercased()] = $1.value ?? ""
        }

        guard let mnemonic = queryItems[Key.mnemonic] else {
            return .failure(.emptyMnemonic)
        }
        let type = queryItems[Key.type].map { UInt8($0) ?? 0 } ?? 0
        guard let cryptoType = MultiassetCryptoType(rawValue: type),
              MultiassetCryptoType.substrateTypeList.contains(cryptoType) else {
            return .failure(.invalidCryptoType)
        }

        let substrateDeriviationPath = queryItems[Key.substrateDeriviationPath]
        if !validateDeriviationPath(substrateDeriviationPath, cryptoType: cryptoType) {
            return .failure(.invalidSubstrateDerivationPath)
        }

        let evmDeriviationPath = queryItems[Key.evmDeriviationPath]
        if !validateDeriviationPath(evmDeriviationPath, cryptoType: .ethereumEcdsa) {
            return .failure(.invalidEvmDerivationPath)
        }

        guard let entropy = try? Data(hexString: mnemonic) else {
            return .failure(.invalidMnemonic)
        }

        do {
            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
            let state = MnemonicDefinition(
                mnemonic: mnemonic,
                cryptoType: cryptoType,
                substrateDeriviationPath: substrateDeriviationPath,
                evmDeriviationPath: evmDeriviationPath ?? DerivationPathConstants.defaultEthereum
            )
            return .success(state)
        } catch {
            return .failure(.invalidMnemonic)
        }
    }

    func validateDeriviationPath(_ path: String?, cryptoType: MultiassetCryptoType) -> Bool {
        guard !path.isNilOrEmpty else {
            return true
        }
        let predicate = deriviationPathPredicate(for: cryptoType)
        return predicate.evaluate(with: path)
    }

    func deriviationPathPredicate(for cryptoType: MultiassetCryptoType) -> NSPredicate {
        switch cryptoType {
        case .sr25519:
            return NSPredicate.deriviationPathHardSoftPassword
        case .ed25519, .substrateEcdsa:
            return NSPredicate.deriviationPathHardPassword
        case .ethereumEcdsa:
            return NSPredicate.deriviationPathHardSoftNumericPassword
        }
    }
}
