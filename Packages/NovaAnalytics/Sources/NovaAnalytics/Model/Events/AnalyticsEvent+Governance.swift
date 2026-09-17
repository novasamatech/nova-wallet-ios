import Foundation

public extension AnalyticsEvent {
    static func governanceVoteCast(
        direction: VoteDirection,
        network: AnalyticsContentValue,
        amount: Decimal,
        rate: Decimal?,
        conviction: ConvictionLevel?
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: .governanceVoteCast,
            properties: [
                .voteDirection: direction,
                .network: network,
                .amountBucket: AmountBucket(amount: amount, rate: rate),
                .convictionLevel: conviction
            ]
        )
    }
}
