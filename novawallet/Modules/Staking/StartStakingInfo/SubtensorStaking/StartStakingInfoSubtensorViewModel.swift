import Foundation
import UIKit

struct StartStakingInfoSubtensorViewModel {
    let title: AccentTextModel?
    let paragraphs: [ParagraphView.Model]
    let actionTitle: String
}

protocol StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createViewModel(
        title: AccentTextModel?,
        locale: Locale
    ) -> StartStakingInfoSubtensorViewModel
}

struct StartStakingInfoSubtensorViewModelFactory:
    StartStakingInfoSubtensorViewModelFactoryProtocol {
    func createViewModel(
        title: AccentTextModel?,
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
            title: title,
            paragraphs: [
                createParagraph(
                    image: R.image.coin(),
                    text: strings.stakingSubtensorUiHowRoot(rootAccent, paidInTaoAccent),
                    accents: [rootAccent, paidInTaoAccent]
                ),
                createParagraph(
                    image: R.image.iconNetworkFallback(),
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
            actionTitle: strings.stakingSubtensorUiHowChooseMyself()
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
}
