import Foundation

enum AmountBucket: String {
    case under1 = "under_1"
    case from1To10 = "1_to_10"
    case from10To100 = "10_to_100"
    case from100To1K = "100_to_1k"
    case from1KTo10K = "1k_to_10k"
    case from10KTo100K = "10k_to_100k"
    case over100K = "over_100k"

    static func from(usdAmount: Decimal) -> AmountBucket {
        switch usdAmount {
        case ..<1: return .under1
        case ..<10: return .from1To10
        case ..<100: return .from10To100
        case ..<1000: return .from100To1K
        case ..<10000: return .from1KTo10K
        case ..<100_000: return .from10KTo100K
        default: return .over100K
        }
    }

    static func from(usdValue: Decimal) -> AmountBucket {
        from(usdAmount: usdValue)
    }
}

enum DurationBucket: String {
    case under5s = "under_5s"
    case from5sTo15s = "5s_to_15s"
    case from15sTo30s = "15s_to_30s"
    case from30sTo60s = "30s_to_60s"
    case from1mTo5m = "1m_to_5m"
    case over5m = "over_5m"

    static func from(milliseconds: Int64) -> DurationBucket {
        let seconds = milliseconds / 1000
        switch seconds {
        case ..<5: return .under5s
        case ..<15: return .from5sTo15s
        case ..<30: return .from15sTo30s
        case ..<60: return .from30sTo60s
        case ..<300: return .from1mTo5m
        default: return .over5m
        }
    }

    static func from(seconds: TimeInterval) -> DurationBucket {
        from(milliseconds: Int64(seconds * 1000))
    }
}

enum SlippageBucket: String {
    case low
    case medium
    case high
    case custom

    static func from(percentage: Double) -> SlippageBucket {
        switch percentage {
        case ...0.5: return .low
        case ...1.0: return .medium
        case ...3.0: return .high
        default: return .custom
        }
    }

    static func from(slippagePercent: Decimal) -> SlippageBucket {
        from(percentage: NSDecimalNumber(decimal: slippagePercent).doubleValue)
    }
}
