import Foundation
import SubstrateSdk
import NovaCrypto
import Foundation_iOS

enum SecretImportDefinition {
    case keystore(KeystoreDefinition)
    case mnemonic(MnemonicDefinition)
}

struct MnemonicDefinition {
    let mnemonic: IRMnemonicProtocol
    let cryptoType: MultiassetCryptoType
    let substrateDeriviationPath: String?
    let evmDeriviationPath: String

    var prefferedInfo: MetaAccountImportPreferredInfo? {
        MetaAccountImportPreferredInfo(
            username: nil,
            cryptoType: cryptoType,
            genesisHash: nil,
            substrateDeriviationPath: substrateDeriviationPath,
            evmDeriviationPath: evmDeriviationPath,
            source: .mnemonic
        )
    }
}

protocol KeystoreImportObserver: AnyObject {
    func didUpdateDefinition(from oldDefinition: SecretImportDefinition?)
    func didReceiveError(secretImportError: ErrorContentConvertible & Error)
}

protocol KeystoreImportServiceProtocol: URLHandlingServiceProtocol {
    var definition: SecretImportDefinition? { get }

    func add(observer: KeystoreImportObserver)

    func remove(observer: KeystoreImportObserver)

    func clear()
}

final class KeystoreImportService {
    private struct ObserverWrapper {
        weak var observer: KeystoreImportObserver?
    }

    private var observers: [ObserverWrapper] = []

    private(set) var definition: SecretImportDefinition?

    let validators: [URLActivityValidator]
    let logger: LoggerProtocol

    init(
        validators: [URLActivityValidator] = [],
        logger: LoggerProtocol
    ) {
        self.validators = validators
        self.logger = logger
    }
}

extension KeystoreImportService: KeystoreImportServiceProtocol {
    func handle(url: URL) -> Bool {
        if !handleDeeplink(url: url) {
            return handleKeystore(url: url)
        } else {
            return true
        }
    }

    private func handleDeeplink(url: URL) -> Bool {
        guard validators.allSatisfy({ $0.validate(url) }) else { return false }

        guard
            let action = UrlHandlingAction(from: url),
            case let .create(screen) = action
        else {
            return false
        }

        guard screen == "wallet" else {
            return false
        }

        switch ImportWalletUrlParsingService().parse(url: url) {
        case let .failure(error):
            observers.forEach { wrapper in
                wrapper.observer?.didReceiveError(secretImportError: error)
            }
        case let .success(state):
            let oldDefinition = definition
            definition = .mnemonic(state)
            observers.forEach { wrapper in
                wrapper.observer?.didUpdateDefinition(from: oldDefinition)
            }
            logger.debug("Imported mnemonic from deeplink")
        }

        return true
    }

    private func handleKeystore(url: URL) -> Bool {
        do {
            guard url.isFileURL else {
                return false
            }

            let data = try Data(contentsOf: url)

            let oldDefinition = definition
            let keystoreDefinition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

            definition = .keystore(keystoreDefinition)

            observers.forEach { wrapper in
                wrapper.observer?.didUpdateDefinition(from: oldDefinition)
            }

            let address = keystoreDefinition.address ?? "no address"
            logger.debug("Imported keystore for address: \(address)")

            return true
        } catch {
            logger.warning("Error while parsing keystore from url: \(error)")
            return false
        }
    }

    func add(observer: KeystoreImportObserver) {
        observers = observers.filter { $0.observer !== nil }

        if observers.contains(where: { $0.observer === observer }) {
            return
        }

        let wrapper = ObserverWrapper(observer: observer)
        observers.append(wrapper)
    }

    func remove(observer: KeystoreImportObserver) {
        observers = observers.filter { $0.observer !== nil && observer !== observer }
    }

    func clear() {
        definition = nil
    }
}
