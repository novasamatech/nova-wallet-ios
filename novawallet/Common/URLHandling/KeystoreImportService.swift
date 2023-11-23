import Foundation
import SubstrateSdk
import IrohaCrypto

enum KeystoreImportDefinition {
    case json(KeystoreDefinition)
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
    func didUpdateDefinition(from oldDefinition: KeystoreImportDefinition?)
}

protocol KeystoreImportServiceProtocol: URLHandlingServiceProtocol {
    var definition: KeystoreImportDefinition? { get }

    func add(observer: KeystoreImportObserver)

    func remove(observer: KeystoreImportObserver)

    func clear()
}

final class KeystoreImportService {
    private struct ObserverWrapper {
        weak var observer: KeystoreImportObserver?
    }

    private var observers: [ObserverWrapper] = []

    private(set) var definition: KeystoreImportDefinition?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
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
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3 else {
            return false
        }
        guard UrlHandlingAction(rawValue: pathComponents[1]) == .create else {
            return false
        }
        let screen = pathComponents[2].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard screen == "wallet" else {
            return false
        }

        switch ImportWalletUrlParsingService().parse(url: url) {
        case .failure:
            return false
        case let .success(state):
            let oldDefinition = definition
            definition = .mnemonic(state)
            observers.forEach { wrapper in
                wrapper.observer?.didUpdateDefinition(from: oldDefinition)
            }
            logger.debug("Imported mnemonic from deeplink")
            return true
        }
    }

    private func handleKeystore(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)

            let oldDefinition = definition
            let keystoreDefinition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

            definition = .json(keystoreDefinition)

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
