import UIKit

final class YourContributionsTableViewCell: BlurredTableViewCell<YourContributionsView> {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        view.apply(style: .navigation)
    }
}

typealias AboutCrowdloansTableViewCell = BlurredTableViewCell<AboutCrowdloansView>

extension BlurredTableViewCell where TContentView == ErrorStateView {
    func applyStyle() {
        view.errorDescriptionLabel.textColor = R.color.colorTextSecondary()
        view.retryButton.titleLabel?.font = .semiBoldSubheadline
        view.stackView.setCustomSpacing(0, after: view.iconImageView)
        view.stackView.setCustomSpacing(8, after: view.errorDescriptionLabel)
        contentInsets = .init(top: 8, left: 16, bottom: 0, right: 16)
        innerInsets = .init(top: 4, left: 0, bottom: 16, right: 0)
    }
}

extension BlurredTableViewCell where TContentView == CrowdloanEmptyView {
    func applyStyle() {
        view.verticalSpacing = 0
        innerInsets = .init(top: 4, left: 0, bottom: 16, right: 0)
        contentInsets = .init(top: 8, left: 16, bottom: 0, right: 16)
    }
}
