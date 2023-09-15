import UIKit
import SubstrateSdk

extension ChainModel {
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
}
