import UIKit

final class DAppFavoriteSettingsView: UITableViewCell {
    var iconDetailsView = IconDetailsView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        iconDetailsView.apply(style: .regularSubheadline)
        iconDetailsView.detailsLabel.textAlignment = .left

        contentView.addSubview(iconDetailsView)
        iconDetailsView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0))
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
