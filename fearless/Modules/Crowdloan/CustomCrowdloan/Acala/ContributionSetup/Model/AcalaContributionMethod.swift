import Foundation

enum AcalaContributionMethod: CaseIterable {
    case direct
    case liquid
}

extension AcalaContributionMethod {
    func title(for _: Locale) -> String {
        switch self {
        case .direct:
            return "Direct"
        case .liquid:
            return "Liquid"
        }
    }
}
