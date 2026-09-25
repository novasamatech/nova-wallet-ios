import Foundation
import BigInt
import Keystore_iOS

final class SubtensorEarnSettings {
    private let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

extension SubtensorEarnSettings: SubtensorEarnSettingsProtocol {
    var slippageTolerance: BigRational {
        get {
            guard
                let stored = settingsManager.value(of: StoredRational.self, for: Key.slippageTolerance),
                let numerator = BigUInt(stored.numerator, radix: 10),
                let denominator = BigUInt(stored.denominator, radix: 10),
                denominator > 0 else {
                return SubtensorSlippageTolerance.defaultTolerance
            }

            return BigRational(numerator: numerator, denominator: denominator)
        }

        set {
            let stored = StoredRational(
                numerator: String(newValue.numerator),
                denominator: String(newValue.denominator)
            )

            settingsManager.set(value: stored, for: Key.slippageTolerance)
        }
    }

    var favouriteSubnets: [SubtensorSubnetRef] {
        get {
            let stored = settingsManager.value(of: [StoredSubnetRef].self, for: Key.favouriteSubnets) ?? []

            return stored.map { SubtensorSubnetRef(netuid: $0.netuid, registeredAt: $0.registeredAt) }
        }

        set {
            let stored = newValue.map { StoredSubnetRef(netuid: $0.netuid, registeredAt: $0.registeredAt) }

            settingsManager.set(value: stored, for: Key.favouriteSubnets)
        }
    }

    var lastStrategy: SubtensorStrategyKind? {
        get {
            settingsManager.string(for: Key.lastStrategy).flatMap(SubtensorStrategyKind.init(rawValue:))
        }

        set {
            if let newValue {
                settingsManager.set(value: newValue.rawValue, for: Key.lastStrategy)
            } else {
                settingsManager.removeValue(for: Key.lastStrategy)
            }
        }
    }
}

private extension SubtensorEarnSettings {
    enum Key {
        static let slippageTolerance = "subtensorEarnSlippageTolerance"
        static let favouriteSubnets = "subtensorEarnFavouriteSubnets"
        static let lastStrategy = "subtensorEarnLastStrategy"
    }

    struct StoredRational: Codable {
        let numerator: String
        let denominator: String
    }

    struct StoredSubnetRef: Codable {
        let netuid: UInt16
        let registeredAt: UInt64
    }
}
