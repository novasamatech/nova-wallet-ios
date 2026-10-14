import UIKit

struct SubtensorWhereToStakeCardModel {
    let order: SubtensorQuickPickOrder
    let title: String
    let subtitle: String
    let prosTitle: String
    let consTitle: String
    let pros: [String]
    let cons: [String]
    let artwork: UIImage?
    let tint: UIColor
    let chooseTitle: String
    let unavailable: String?
}

struct SubtensorWhereToStakeViewModelFactory {
    func create(order: SubtensorQuickPickOrder, locale: Locale) -> SubtensorWhereToStakeCardModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let title: String
        let subtitle: String
        let pros: [String]
        let cons: [String]
        let artwork: UIImage?
        let tint: UIColor
        switch order {
        case .poolSize:
            title = strings.stakingSubtensorQuickPoolTitle()
            subtitle = strings.stakingSubtensorQuickPoolOrder()
            pros = [strings.stakingSubtensorQuickPoolProOne(), strings.stakingSubtensorQuickPoolProTwo()]
            cons = [strings.stakingSubtensorQuickPoolConOne(), strings.stakingSubtensorQuickPoolConTwo()]
            artwork = R.image.subtensorQuickPool()
            tint = R.color.colorQuickPickPool()!
        case .age:
            title = strings.stakingSubtensorUiPickerAge()
            subtitle = strings.stakingSubtensorQuickAgeOrder()
            pros = [strings.stakingSubtensorQuickAgePro()]
            cons = [strings.stakingSubtensorQuickAgeConOne(), strings.stakingSubtensorQuickAgeConTwo()]
            artwork = R.image.clock()
            tint = R.color.colorQuickPickAge()!
        case .apy:
            title = strings.stakingSubtensorUiValidatorSortApy()
            subtitle = strings.stakingSubtensorQuickApyOrder()
            pros = [strings.stakingSubtensorQuickApyPro()]
            cons = [strings.stakingSubtensorQuickApyConOne(), strings.stakingSubtensorQuickApyConTwo()]
            artwork = R.image.cup()
            tint = R.color.colorQuickPickApy()!
        case .root:
            title = strings.stakingSubtensorQuickRootTitle()
            subtitle = strings.stakingSubtensorQuickRootOrder()
            pros = [strings.stakingSubtensorQuickRootProOne(), strings.stakingSubtensorQuickRootProTwo()]
            cons = []
            artwork = R.image.coin()
            tint = R.color.colorQuickPickRoot()!
        }
        return SubtensorWhereToStakeCardModel(
            order: order, title: title, subtitle: subtitle,
            prosTitle: strings.stakingSubtensorQuickPros(), consTitle: strings.stakingSubtensorQuickCons(),
            pros: pros, cons: cons, artwork: artwork, tint: tint,
            chooseTitle: strings.stakingSubtensorQuickChoose(),
            unavailable: order.isAvailable ? nil : strings.stakingSubtensorQuickApyUnavailable()
        )
    }
}
