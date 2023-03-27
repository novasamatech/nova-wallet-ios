import UIKit

typealias GovernanceDelegateCellValueView = IconDetailsGenericView<GenericPairValueView<BorderedImageView, UILabel>>

final class GovernanceDelegateStackCell: RowView<GenericTitleValueView<UILabel, GovernanceDelegateCellValueView>> {
    var titleLabel: UILabel {
        rowContentView.titleView
    }

    var delegateLabel: UILabel {
        rowContentView.valueView.detailsView.sView
    }

    var delegateIconView: BorderedImageView {
        rowContentView.valueView.detailsView.fView
    }

    let iconSize = CGSize(width: 20, height: 20)

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyStyle()
    }

    private func applyStyle() {
        titleLabel.apply(style: .footnoteSecondary)
        delegateLabel.apply(style: .footnotePrimary)

        rowContentView.valueView.mode = .detailsIcon
        rowContentView.valueView.detailsView.makeHorizontal()
        rowContentView.valueView.detailsView.spacing = 8
        rowContentView.valueView.spacing = 8
        rowContentView.valueView.imageView.image = R.image.iconInfoFilled()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
    }

    private func setupLayout() {
        delegateIconView.snp.makeConstraints { make in
            make.size.equalTo(iconSize)
        }
    }

    func bind(viewModel: GovernanceDelegateStackCell.Model) {
        delegateLabel.lineBreakMode = viewModel.addressViewModel.lineBreakMode

        let cellViewModel = viewModel.addressViewModel.cellViewModel

        delegateLabel.text = cellViewModel.details

        delegateIconView.hidesBorder = viewModel.type == nil

        delegateIconView.bind(
            viewModel: cellViewModel.imageViewModel,
            targetSize: iconSize,
            delegateType: viewModel.type
        )
    }
}

extension GovernanceDelegateStackCell: StackTableViewCellProtocol {}

extension GovernanceDelegateStackCell {
    struct Model {
        let addressViewModel: DisplayAddressViewModel
        let type: GovernanceDelegateTypeView.Model?
    }
}
