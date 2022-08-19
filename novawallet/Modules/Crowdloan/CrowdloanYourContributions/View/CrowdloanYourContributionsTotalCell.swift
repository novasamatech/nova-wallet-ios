import UIKit

final class CrowdloanYourContributionsTotalCell: BlurredTableViewCell<YourContributionsView> {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        view.apply(style: .readonly)
    }
}
