import UIKit

final class StackActionCell: RowView<StackActionView>, StackTableViewCellProtocol {
    var titleLabel: UILabel { rowContentView.titleLabel }
    var imageView: UIImageView { rowContentView.iconImageView }
    var detailsView: BorderedLabelView { rowContentView.detailsView }

    func bind(title: String, icon: UIImage?, details: String?) {
        titleLabel.text = title
        imageView.image = icon
        detailsView.titleLabel.text = details

        let shouldHideDetails = (details ?? "").isEmpty
        detailsView.isHidden = shouldHideDetails
    }
}
