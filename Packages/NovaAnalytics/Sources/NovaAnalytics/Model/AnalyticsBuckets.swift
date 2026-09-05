import Foundation

/// Boundaries and raw values transcribed from
/// `analytics/src/main/java/io/novafoundation/nova/analytics/ValueBucketing.kt`.
/// The raw values are the wire contract; the Swift case names are not.
public enum AmountBucket: String, AnalyticsPropertyConvertible {
    case under1 = "under_1"
    case from1To10 = "1_to_10"
    case from10To100 = "10_to_100"
    case from100To1k = "100_to_1k"
    case from1kTo10k = "1k_to_10k"
    case from10kTo100k = "10k_to_100k"
    case over100k = "over_100k"

    public init(usd: Decimal) {
        self = if usd < 1 {
            .under1
        } else if usd < 10 {
            .from1To10
        } else if usd < 100 {
            .from10To100
        } else if usd < 1000 {
            .from100To1k
        } else if usd < 10000 {
            .from1kTo10k
        } else if usd < 100_000 {
            .from10kTo100k
        } else {
            .over100k
        }
    }

    /// Send and staking always emit: Android calls `amountToFiat` unguarded, so a missing
    /// rate becomes 0 rather than a skipped event.
    public init(amount: Decimal, rate: Decimal?) {
        self.init(usd: amount * (rate ?? 0))
    }

    /// Swap only: Android skips swap events without a fiat rate for the pay asset.
    ///
    /// Takes the rate rather than the app's `PriceData`, which is a wallet domain model and
    /// cannot cross the boundary. The caller passes `priceData?.decimalRate`, so a price
    /// that is absent and a price whose string will not parse both still yield `nil` here.
    public init?(amount: Decimal, price: Decimal?) {
        guard let rate = price else { return nil }

        self.init(usd: amount * rate)
    }
}

public enum DurationBucket: String, AnalyticsPropertyConvertible {
    case under5s = "under_5s"
    case from5sTo15s = "5s_to_15s"
    case from15sTo30s = "15s_to_30s"
    case from30sTo60s = "30s_to_60s"
    case from1mTo5m = "1m_to_5m"
    case over5m = "over_5m"

    /// Truncating to whole seconds reproduces Android's `milliseconds / 1000`
    /// integer division.
    public init(duration: TimeInterval) {
        self = switch Int(duration) {
        case ..<5: .under5s
        case ..<15: .from5sTo15s
        case ..<30: .from15sTo30s
        case ..<60: .from30sTo60s
        case ..<300: .from1mTo5m
        default: .over5m
        }
    }
}

public enum SlippageBucket: String, AnalyticsPropertyConvertible {
    case low
    case medium
    case high
    case custom

    /// Bounds are INCLUSIVE on Android (`percentage <= 0.5 -> LOW`), unlike the
    /// exclusive amount and duration bounds.
    public init(percent: Decimal) {
        self = if percent <= 0.5 {
            .low
        } else if percent <= 1 {
            .medium
        } else if percent <= 3 {
            .high
        } else {
            .custom
        }
    }
}
