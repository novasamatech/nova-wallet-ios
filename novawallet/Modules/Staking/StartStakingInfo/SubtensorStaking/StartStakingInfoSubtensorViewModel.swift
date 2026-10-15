import Foundation
import Foundation_iOS
import UIKit

struct StartStakingInfoSubtensorViewModel {
    let title: AccentTextModel
    let paragraphs: [ParagraphView.Model]
    let actionTitle: String
}

protocol StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createViewModel(
        headlineRate: Decimal?,
        symbol: String,
        locale: Locale
    ) -> StartStakingInfoSubtensorViewModel
}

struct StartStakingInfoSubtensorViewModelFactory:
    StartStakingInfoSubtensorViewModelFactoryProtocol {
    let percentFormatter: LocalizableResource<NumberFormatter>

    func createViewModel(
        headlineRate: Decimal?,
        symbol: String,
        locale: Locale
    ) -> StartStakingInfoSubtensorViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let rootAccent = strings.stakingSubtensorUiHowRootAccent()
        let paidInTaoAccent = strings.stakingSubtensorUiHowPaidInTaoAccent()
        let subnetTokenAccent = strings.stakingSubtensorUiHowSubnetTokenAccent()
        let marketAccent = strings.stakingSubtensorUiHowMarketAccent()
        let everyDayAccent = strings.stakingSubtensorUiHowEveryDayAccent()
        let anyTimeAccent = strings.stakingSubtensorUiHowAnyTimeAccent()

        return .init(
            title: createTitle(headlineRate: headlineRate, symbol: symbol, locale: locale),
            paragraphs: [
                createParagraph(
                    image: R.image.coin(),
                    text: strings.stakingSubtensorUiHowRoot(rootAccent, paidInTaoAccent),
                    accents: [rootAccent, paidInTaoAccent]
                ),
                createParagraph(
                    image: R.image.subnets(),
                    text: strings.stakingSubtensorUiHowSubnet(subnetTokenAccent, marketAccent),
                    accents: [subnetTokenAccent, marketAccent]
                ),
                createParagraph(
                    image: R.image.cup(),
                    text: strings.stakingSubtensorUiHowRewards(everyDayAccent),
                    accents: [everyDayAccent]
                ),
                createParagraph(
                    image: R.image.clock(),
                    text: strings.stakingSubtensorUiHowUnstake(anyTimeAccent),
                    accents: [anyTimeAccent]
                )
            ],
            actionTitle: strings.stakingSubtensorUiHowAction()
        )
    }
}

private extension StartStakingInfoSubtensorViewModelFactory {
    func createTitle(headlineRate: Decimal?, symbol: String, locale: Locale) -> AccentTextModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard
            let headlineRate,
            let rate = percentFormatter.value(for: locale).stringFromDecimal(headlineRate) else {
            return AccentTextModel(text: strings.stakingStakeFormat(symbol), accents: [symbol])
        }

        let accent = strings.stakingStartEarnUp(rate)

        return AccentTextModel(text: strings.stakingSubtensorUiHowTitle(accent, symbol), accents: [accent])
    }

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
}
