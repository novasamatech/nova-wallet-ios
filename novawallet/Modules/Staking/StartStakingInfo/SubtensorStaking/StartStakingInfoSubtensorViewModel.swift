import Foundation
import UIKit

struct StartStakingInfoSubtensorViewModel {
    let title: AccentTextModel
    let paragraphs: [ParagraphView.Model]
    let primaryActionTitle: String
    let secondaryActionTitle: String
}

protocol StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createViewModel(
        from strategies: [SubtensorStakingStrategy],
        locale: Locale
    ) -> StartStakingInfoSubtensorViewModel
}

struct StartStakingInfoSubtensorViewModelFactory:
    StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createViewModel(
        from strategies: [SubtensorStakingStrategy],
        locale: Locale
    ) -> StartStakingInfoSubtensorViewModel {
        let maximumReturn = strategies.map(\.annualReturn).max() ?? 0.40
        let formattedReturn = formatPercent(maximumReturn, locale: locale)
        let highlightedTitle = "Earn up to \(formattedReturn)"

        return .init(
            title: .init(
                text: "\(highlightedTitle)\non your TAO tokens per year",
                accents: [highlightedTitle]
            ),
            paragraphs: [
                createParagraph(
                    image: R.image.coin(),
                    text: "Stake to root and keep your TAO as TAO — rewards are paid in TAO",
                    accents: ["root", "paid in TAO"]
                ),
                createParagraph(
                    image: R.image.iconNetworkFallback(),
                    text: "Or swap TAO for a subnet token: earn daily rewards in that token and gain on its growth. Its value moves with the market",
                    accents: ["subnet token", "moves with the market"]
                ),
                createParagraph(
                    image: R.image.cup(),
                    text: "Rewards accrue every day and add up automatically",
                    accents: ["every day"]
                ),
                createParagraph(
                    image: R.image.clock(),
                    text: "Unstake any time — no waiting period in either lane. Every rate you see is an estimate",
                    accents: ["any time"]
                )
            ],
            primaryActionTitle: "Start earning",
            secondaryActionTitle: "I'll choose myself"
        )
    }
}

private extension StartStakingInfoSubtensorViewModelFactory {
    func createParagraph(
        image: UIImage?,
        text: String,
        accents: [String]
    ) -> ParagraphView.Model {
        .init(
            image: image,
            text: .init(text: text, accents: accents)
        )
    }

    func formatPercent(_ value: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        return formatter.string(from: value as NSDecimalNumber) ?? "40%"
    }
}
