import UIKit

final class DAppFavoriteSettingsView: RowView<IconDetailsView> {
    var iconDetailsView: IconDetailsView { rowContentView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        rowContentView.apply(style: .regularSubheadline)
        rowContentView.detailsLabel.textAlignment = .left
        preferredHeight = 52
        contentInsets = .init(top: 16, left: 0, bottom: 16, right: 0)
        borderView.borderType = .none
    }
}
