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

    var favouriteSubnets: Set<SubtensorSubnetRef> {
        get {
            Set(settingsManager.value(of: [SubtensorSubnetRef].self, for: Key.favouriteSubnets) ?? [])
        }

        set {
            let stored = newValue.sorted { ($0.netuid, $0.registeredAt) < ($1.netuid, $1.registeredAt) }

            settingsManager.set(value: stored, for: Key.favouriteSubnets)
        }
    }
}

private extension SubtensorEarnSettings {
    enum Key {
        static let slippageTolerance = "subtensorEarnSlippageTolerance"
        static let favouriteSubnets = "subtensorEarnFavouriteSubnets"
    }

    struct StoredRational: Codable {
        let numerator: String
        let denominator: String
    }
}
