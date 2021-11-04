import Foundation

enum AcalaContributionMethod: CaseIterable {
    case direct
    case liquid
}

extension AcalaContributionMethod {
    func title(for locale: Locale) -> String {
        switch self {
        case .direct:
            return R.string.localizable.crowdloanAcalaDirect(preferredLanguages: locale.rLanguages)
        case .liquid:
            return R.string.localizable.crowdloanAcalaLiquid(preferredLanguages: locale.rLanguages)
        }
    }
}
