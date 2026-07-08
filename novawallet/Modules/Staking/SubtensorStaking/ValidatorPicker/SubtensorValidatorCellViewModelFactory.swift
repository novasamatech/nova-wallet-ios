import Foundation
import UIKit
import BigInt
import SubstrateSdk

/// Builds `SubtensorValidatorCellViewModel` from a `SubtensorValidator`.
///
/// Lives next to the cell so the picker view controller doesn't have to
/// pull in BalanceViewModelFactory or worry about identicon generation.
/// All formatting decisions (commission percent, total stake compact form,
/// short hotkey rendering) are centralised here so subnet variants can swap
/// individual format helpers without touching the cell or the controller.
final class SubtensorValidatorCellViewModelFactory {
    /// Pre-formatted suffix for total stake. v1 root subnet: "TAO" (the
    /// utility-asset symbol on Bittensor). Subnet variants will pass an
    /// alpha-token symbol when v2 lands.
    private let stakeSymbol: String

    /// Number of fractional digits in TAO. Bittensor uses 9 RAO/TAO.
    private let assetPrecision: UInt16

    private let iconGenerator = PolkadotIconGenerator()

    private let percentFormatter: NumberFormatter
    private let compactStakeFormatter: NumberFormatter

    init(
        stakeSymbol: String = "TAO",
        assetPrecision: UInt16 = 9
    ) {
        self.stakeSymbol = stakeSymbol
        self.assetPrecision = assetPrecision

        percentFormatter = {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.numberStyle = .decimal
            return formatter
        }()

        compactStakeFormatter = {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 2
            formatter.numberStyle = .decimal
            return formatter
        }()
    }

    func create(from validator: SubtensorValidator, netuid: UInt16) -> SubtensorValidatorCellViewModel {
        let identicon = try? iconGenerator.generateFromAccountId(validator.hotkey)

        let address = (try? validator.hotkey.toAddressWithDefaultConversion()) ?? validator.hotkey.toHex()
        let shortHotkey = Self.shorten(address: address)

        let displayName = (validator.identity?.isEmpty == false) ? validator.identity : nil
        let aprText = formatApr(validator.apr)
        let commissionText = formatCommissionCaption(validator.commission)
        let totalStakeText = formatTotalStake(validator.totalStake)

        return SubtensorValidatorCellViewModel(
            hotkey: validator.hotkey,
            netuid: netuid,
            identicon: identicon,
            displayName: displayName,
            shortHotkey: shortHotkey,
            aprText: aprText,
            commissionText: commissionText,
            totalStakeText: totalStakeText,
            // v1 root subnet has no badge. Subnet variants would inject
            // a label like "Subnet 3" here.
            subnetBadge: nil
        )
    }

    /// Renders APR as a percent with two decimal places, e.g.
    /// `0.4550` -> `"45.50%"`. Returns `"—"` when APR is unavailable
    /// (validator absent from the TaoStats sample). APR is post-commission.
    private func formatApr(_ apr: Double?) -> String {
        guard let apr else { return "—" }
        let percent = apr * 100
        let number = NSNumber(value: percent)
        let body = percentFormatter.string(from: number) ?? "0.00"
        return "\(body)%"
    }

    /// Renders the commission caption, e.g. `0.18` -> `"18% commission"`.
    /// Used as the gray aux line below APR.
    private func formatCommissionCaption(_ commission: Double) -> String {
        let percent = commission * 100
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .decimal
        let body = formatter.string(from: NSNumber(value: percent)) ?? "0"
        return "\(body)% commission"
    }

    /// Compact total stake formatter. v1 produces strings like
    /// `"1.2M TAO"`, `"500K TAO"`, `"5 TAO"`. Bittensor stake is denominated
    /// in RAO (1 TAO = 10^9 RAO) so we divide before applying the compact
    /// suffix. The provider currently returns 0 for all stake stubs — this
    /// formatter handles the eventual real numbers without changes.
    private func formatTotalStake(_ rao: BigUInt) -> String {
        guard rao > 0 else {
            return "0 \(stakeSymbol)"
        }

        // RAO -> TAO via Decimal to avoid Double imprecision on extreme values.
        let raoString = String(rao)
        guard let raoDecimal = Decimal(string: raoString) else {
            return "0 \(stakeSymbol)"
        }
        let divisor = pow(Decimal(10), Int(assetPrecision))
        let taoDecimal = raoDecimal / divisor

        let (suffix, scale): (String, Decimal) = {
            if taoDecimal >= Decimal(1_000_000_000) {
                return ("B", Decimal(1_000_000_000))
            } else if taoDecimal >= Decimal(1_000_000) {
                return ("M", Decimal(1_000_000))
            } else if taoDecimal >= Decimal(1000) {
                return ("K", Decimal(1000))
            } else {
                return ("", Decimal(1))
            }
        }()

        let scaled = (taoDecimal as NSDecimalNumber).dividing(by: scale as NSDecimalNumber)
        let body = compactStakeFormatter.string(from: scaled) ?? "0"
        return "\(body)\(suffix) \(stakeSymbol)"
    }

    /// Renders an address as `"5E2L...eZ5u"` for compact display. Anything
    /// shorter than 11 characters is returned unchanged.
    static func shorten(address: String) -> String {
        guard address.count > 10 else { return address }
        let head = address.prefix(6)
        let tail = address.suffix(4)
        return "\(head)...\(tail)"
    }
}
