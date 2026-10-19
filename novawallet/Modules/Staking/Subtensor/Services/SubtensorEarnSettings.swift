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
            let key = SettingsKey.subtensorEarnSlippageTolerance.rawValue

            guard
                let stored = settingsManager.value(of: StoredRational.self, for: key),
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

            settingsManager.set(value: stored, for: SettingsKey.subtensorEarnSlippageTolerance.rawValue)
        }
    }

    var favouriteSubnets: Set<SubtensorSubnetRef> {
        get {
            let key = SettingsKey.subtensorEarnFavouriteSubnets.rawValue

            return Set(settingsManager.value(of: [SubtensorSubnetRef].self, for: key) ?? [])
        }

        set {
            let stored = newValue.sorted { ($0.netuid, $0.registeredAt) < ($1.netuid, $1.registeredAt) }

            settingsManager.set(value: stored, for: SettingsKey.subtensorEarnFavouriteSubnets.rawValue)
        }
    }
}

private extension SubtensorEarnSettings {
    struct StoredRational: Codable {
        let numerator: String
        let denominator: String
    }
}
