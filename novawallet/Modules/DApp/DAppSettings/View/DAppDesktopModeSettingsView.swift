import UIKit

final class DAppDesktopModeSettingsView: RowView<DAppSettingsView> {
    var iconDetailsView: IconDetailsView { rowContentView.iconDetailsView }
    var switchView: UISwitch { rowContentView.switchView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconDetailsView.apply(style: .regularSubheadline)
        iconDetailsView.detailsLabel.textAlignment = .left
        preferredHeight = 52
        contentInsets = .init(top: 16, left: 0, bottom: 16, right: 0)
        borderView.borderType = .none
    }
}
