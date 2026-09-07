import Foundation

public enum AmountBucket: String, CaseIterable, AnalyticsPropertyConvertible {
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

    public init(amount: Decimal, rate: Decimal?) {
        self.init(usd: amount * (rate ?? 0))
    }

    public init?(amount: Decimal, price: Decimal?) {
        guard let rate = price else { return nil }

        self.init(usd: amount * rate)
    }
}

public enum DurationBucket: String, CaseIterable, AnalyticsPropertyConvertible {
    case under5s = "under_5s"
    case from5sTo15s = "5s_to_15s"
    case from15sTo30s = "15s_to_30s"
    case from30sTo60s = "30s_to_60s"
    case from1mTo5m = "1m_to_5m"
    case over5m = "over_5m"

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

public enum SlippageBucket: String, CaseIterable, AnalyticsPropertyConvertible {
    case low
    case medium
    case high
    case custom

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

public enum NftCountBucket: String, CaseIterable, AnalyticsPropertyConvertible {
    case none = "0"
    case from1To10 = "1_to_10"
    case from10To100 = "10_to_100"
    case over100 = "over_100"

    public init(count: Int) {
        self = if count < 1 {
            .none
        } else if count < 10 {
            .from1To10
        } else if count < 100 {
            .from10To100
        } else {
            .over100
        }
    }
}
