import UIKit

struct SubtensorWhereToStakeCardModel {
    struct Palette {
        let border: UIColor
        let gradient: [UIColor]
        let mark: UIColor
    }

    let order: SubtensorQuickPickOrder
    let title: String
    let subtitle: String
    let prosTitle: String
    let consTitle: String
    let pros: [String]
    let cons: [String]
    let artwork: UIImage?
    let palette: Palette
    let chooseTitle: String
}

struct SubtensorWhereToStakeViewModelFactory {
    func create(order: SubtensorQuickPickOrder, locale: Locale) -> SubtensorWhereToStakeCardModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let title: String
        let subtitle: String
        let pros: [String]
        let cons: [String]
        switch order {
        case .poolSize:
            title = strings.stakingSubtensorQuickPoolTitle()
            subtitle = strings.stakingSubtensorQuickPoolOrder()
            pros = [strings.stakingSubtensorQuickPoolProOne(), strings.stakingSubtensorQuickPoolProTwo()]
            cons = [strings.stakingSubtensorQuickPoolConOne(), strings.stakingSubtensorQuickPoolConTwo()]
        case .age:
            title = strings.stakingSubtensorUiPickerAge()
            subtitle = strings.stakingSubtensorQuickAgeOrder()
            pros = [strings.stakingSubtensorQuickAgePro()]
            cons = [strings.stakingSubtensorQuickAgeConOne(), strings.stakingSubtensorQuickAgeConTwo()]
        case .apy:
            title = strings.stakingSubtensorUiValidatorSortApy()
            subtitle = strings.stakingSubtensorQuickApyOrder()
            pros = [strings.stakingSubtensorQuickApyPro()]
            cons = [strings.stakingSubtensorQuickApyConOne(), strings.stakingSubtensorQuickApyConTwo()]
        case .root:
            title = strings.stakingSubtensorQuickRootTitle()
            subtitle = strings.stakingSubtensorQuickRootOrder()
            pros = [strings.stakingSubtensorQuickRootProOne(), strings.stakingSubtensorQuickRootProTwo()]
            cons = []
        }
        return SubtensorWhereToStakeCardModel(
            order: order, title: title, subtitle: subtitle,
            prosTitle: strings.stakingSubtensorQuickPros(), consTitle: strings.stakingSubtensorQuickCons(),
            pros: pros, cons: cons, artwork: order.artwork, palette: order.palette,
            chooseTitle: strings.stakingSubtensorQuickChoose()
        )
    }
}

private extension SubtensorQuickPickOrder {
    var artwork: UIImage? {
        switch self {
        case .poolSize: return R.image.subtensorQuickPool()
        case .age: return R.image.subtensorQuickAge()
        case .apy: return R.image.subtensorQuickApy()
        case .root: return R.image.subtensorQuickRoot()
        }
    }

    var palette: SubtensorWhereToStakeCardModel.Palette {
        switch self {
        case .poolSize:
            return .init(
                border: R.color.colorQuickPickPoolBorder()!,
                gradient: [
                    R.color.colorQuickPickPoolGradientStart()!,
                    R.color.colorQuickPickPoolGradientMiddle()!,
                    R.color.colorQuickPickPoolGradientEnd()!
                ],
                mark: R.color.colorQuickPickPoolMark()!
            )
        case .age:
            return .init(
                border: R.color.colorQuickPickAgeBorder()!,
                gradient: [
                    R.color.colorQuickPickAgeGradientStart()!,
                    R.color.colorQuickPickAgeGradientMiddle()!,
                    R.color.colorQuickPickAgeGradientEnd()!
                ],
                mark: R.color.colorQuickPickAgeMark()!
            )
        case .apy:
            return .init(
                border: R.color.colorQuickPickApyBorder()!,
                gradient: [
                    R.color.colorQuickPickApyGradientStart()!,
                    R.color.colorQuickPickApyGradientMiddle()!,
                    R.color.colorQuickPickApyGradientEnd()!
                ],
                mark: R.color.colorQuickPickApyMark()!
            )
        case .root:
            return .init(
                border: R.color.colorQuickPickRootBorder()!,
                gradient: [
                    R.color.colorQuickPickRootGradientStart()!,
                    R.color.colorQuickPickRootGradientMiddle()!,
                    R.color.colorQuickPickRootGradientEnd()!
                ],
                mark: R.color.colorQuickPickRootMark()!
            )
        }
    }
}
