import UIKit

typealias GovernanceDelegateCellValueView = IconDetailsGenericView<GenericPairValueView<DAppIconView, UILabel>>

final class GovernanceDelegateCell: RowView<GenericTitleValueView<UILabel, GovernanceDelegateCellValueView>> {
    var titleLabel: UILabel {
        rowContentView.titleView
    }

    var delegateLabel: UILabel {
        rowContentView.valueView.detailsView.sView
    }

    var delegateIconView: DAppIconView {
        rowContentView.valueView.detailsView.fView
    }

    let iconSize: CGSize = CGSize(width: 20, height: 20)

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
        delegateIconView.contentInsets = .zero

        rowContentView.valueView.mode = .detailsIcon
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

    func bind(viewModel: GovernanceDelegateCell.Model) {
        delegateLabel.lineBreakMode = viewModel.addressViewModel.lineBreakMode

        let cellViewModel = viewModel.addressViewModel.cellViewModel

        delegateLabel.text = cellViewModel.details

        switch viewModel.type {
        case .individual, .none:
            delegateIconView.backgroundView.apply(style: .clear)

            cellViewModel.imageViewModel?.loadImage(
                on: delegateIconView.imageView,
                targetSize: iconSize,
                cornerRadius: iconSize.height / 2.0,
                animated: true
            )
        case .organization:
            let iconRadius = floor(iconSize.height / 5.0)
            delegateIconView.backgroundView.apply(style: .roundedContainerWithShadow(radius: iconRadius))

            cellViewModel.imageViewModel?.loadImage(
                on: delegateIconView.imageView,
                targetSize: iconSize,
                animated: true
            )
        }
    }
}

extension GovernanceDelegateCell: StackTableViewCellProtocol {}

extension GovernanceDelegateCell {
    struct Model {
        let addressViewModel: DisplayAddressViewModel
        let type: GovernanceDelegateTypeView.Model?
    }
}
