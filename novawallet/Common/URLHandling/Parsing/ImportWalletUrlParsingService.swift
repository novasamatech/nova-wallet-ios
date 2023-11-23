import Foundation
import RobinHood
import IrohaCrypto

enum CreateWalletError: Error {
    case emptyMnemonic
    case invalidMnemonic
    case invalidCryptoType
    case invalidSubstrateDerivationPath
    case invalidEvmDerivationPath
    case emptyQueryParameters
}

final class ImportWalletUrlParsingService {
    enum Key {
        static let mnemonic = "mnemonic"
        static let type = "cryptotype"
        static let substrateDeriviationPath = "substratedp"
        static let evmDeriviationPath = "evmdp"
    }

    func parse(url: URL) -> Result<ImportWalletInitState, CreateWalletError> {
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
        guard let cryptoType = MultiassetCryptoType(rawValue: type), cryptoType != .ethereumEcdsa else {
            return .failure(.invalidCryptoType)
        }

        let substrateDeriviationPath = queryItems[Key.substrateDeriviationPath]
        if !validateDeriviationPath(substrateDeriviationPath, cryptoType: cryptoType) {
            return .failure(.invalidSubstrateDerivationPath)
        }

        let evmDeriviationPath = queryItems[Key.evmDeriviationPath]
        if !validateDeriviationPath(evmDeriviationPath, cryptoType: cryptoType) {
            return .failure(.invalidEvmDerivationPath)
        }

        guard let entropy = try? Data(hexString: mnemonic) else {
            return .failure(.invalidMnemonic)
        }

        do {
            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
            let state = ImportWalletInitState(
                mnemonic: mnemonic,
                cryptoType: cryptoType,
                substrateDerivationPath: substrateDeriviationPath,
                evmDerivationPath: evmDeriviationPath ?? DerivationPathConstants.defaultEthereum
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
        if cryptoType == .sr25519 {
            return NSPredicate.deriviationPathHardSoftPassword
        } else {
            return NSPredicate.deriviationPathHardPassword
        }
    }
}
