import UIKit
import SubstrateSdk

extension ChainModel {
    enum NewFeature: String {
        case staking
    }

    var themeColor: UIColor? {
        guard let hexColor = additional?.themeColor?.stringValue else {
            return nil
        }

        return UIColor(hex: hexColor)
    }

    var stakingWiki: URL? {
        guard let wiki = additional?.stakingWiki?.stringValue else {
            return nil
        }

        return URL(string: wiki)
    }

    var newFeatures: Set<NewFeature> {
        let values = additional?.newFeatures?.arrayValue ?? []

        return Set(values.compactMap { $0.stringValue.flatMap(NewFeature.init(rawValue:)) })
    }
}
