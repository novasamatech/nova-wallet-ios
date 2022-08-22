import Foundation

struct CrowdloanYourContributionsViewModel {
    let sections: [CrowdloanYourContributionsSection]
}

enum CrowdloanYourContributionsSection {
    case total(YourContributionsView.Model)
    case contributions([CrowdloanContributionViewModel])
}
