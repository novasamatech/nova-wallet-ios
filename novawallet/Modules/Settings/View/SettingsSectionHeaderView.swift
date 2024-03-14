import UIKit

final class SettingsSectionHeaderView: SectionTextHeaderView {
    override func setupLayout() {
        super.setupLayout()
        horizontalOffset = 20
        bottomOffset = 12
    }
}

final class SettingsSectionFooterView: SectionTextHeaderView {
    override func setupLayout() {
        super.setupLayout()
        horizontalOffset = 12
        bottomOffset = 12
        titleLabel.apply(style: .caption1Secondary)
        titleLabel.numberOfLines = 0
    }
}
