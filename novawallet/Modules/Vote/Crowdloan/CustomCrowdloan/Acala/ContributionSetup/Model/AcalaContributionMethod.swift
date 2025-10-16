import Foundation

enum AcalaContributionMethod: CaseIterable {
    case direct
    case liquid
}

extension AcalaContributionMethod {
    func title(for locale: Locale) -> String {
        switch self {
        case .direct:
            return R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanAcalaDirect()
        case .liquid:
            return R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanAcalaLiquid()
        }
    }
}
