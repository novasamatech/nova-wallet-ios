import Foundation

enum AssetExchangeFeeConstants {
    // we keep 10% buffer for fee since swaps to native asset especially volatile
    static let feeBufferInPercentage = BigRational.percent(of: 10)
}
