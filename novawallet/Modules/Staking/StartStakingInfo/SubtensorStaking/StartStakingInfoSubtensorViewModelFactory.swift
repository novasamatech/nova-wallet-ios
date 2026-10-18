import Foundation
import UIKit

protocol StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createCaption(locale: Locale) -> String
    func createParagraphs(locale: Locale) -> [ParagraphView.Model]
}

struct StartStakingInfoSubtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createCaption(locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiHowCaption()
    }

    func createParagraphs(locale: Locale) -> [ParagraphView.Model] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let paidInTaoAccent = strings.stakingSubtensorUiHowPaidInTaoAccent()
        let riseOrFallAccent = strings.stakingSubtensorUiHowRiseOrFallAccent()
        let everyDayAccent = strings.stakingSubtensorUiHowEveryDayAccent()
        let anyTimeAccent = strings.stakingSubtensorUiHowAnyTimeAccent()

        return [
            createParagraph(
                image: R.image.coin(),
                text: strings.stakingSubtensorUiHowRoot(paidInTaoAccent),
                accent: paidInTaoAccent
            ),
            createParagraph(
                image: R.image.subnets(),
                text: strings.stakingSubtensorUiHowSubnet(riseOrFallAccent),
                accent: riseOrFallAccent
            ),
            createParagraph(
                image: R.image.cup(),
                text: strings.stakingSubtensorUiHowRewards(everyDayAccent),
                accent: everyDayAccent
            ),
            createParagraph(
                image: R.image.clock(),
                text: strings.stakingSubtensorUiHowUnstake(anyTimeAccent),
                accent: anyTimeAccent
            )
        ]
    }
}

private extension StartStakingInfoSubtensorViewModelFactory {
    func createParagraph(image: UIImage?, text: String, accent: String) -> ParagraphView.Model {
        ParagraphView.Model(image: image, text: AccentTextModel(text: text, accents: [accent]))
    }
}
