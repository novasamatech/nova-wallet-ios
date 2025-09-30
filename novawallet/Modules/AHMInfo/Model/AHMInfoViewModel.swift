import UIKit

struct AHMInfoViewModel {
    let bannerState: BannersState
    let title: String
    let subtitle: String
    let features: [Feature]
    let info: [Info]
    let actionButtonTitle: String

    struct Feature {
        let emoji: String
        let text: String
    }

    struct Info {
        let type: InfoType
        let text: String
    }
}

extension AHMInfoViewModel.Info {
    enum InfoType {
        case history
        case migration
    }
}
