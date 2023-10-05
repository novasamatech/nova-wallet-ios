import Foundation
import UIKit

final class StackTitleMultiValueEditCell: RowView<GenericTitleValueView<IconDetailsView, GenericPairValueView<IconDetailsView, UILabel>>> {
    var titleLabel: UILabel { rowContentView.titleView.detailsLabel }
    var titleImageView: UIImageView { rowContentView.titleView.imageView }
    var topValueImageView: UIImageView { rowContentView.valueView.fView.imageView }
    var topValueLabel: UILabel { rowContentView.valueView.fView.detailsLabel }
    var bottomValueLabel: UILabel { rowContentView.valueView.sView }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        titleLabel.textColor = R.color.colorTextSecondary()
        titleLabel.font = .regularFootnote
        titleImageView.image = R.image.iconInfoFilledAccent()

        rowContentView.titleView.mode = .detailsIcon
        rowContentView.titleView.spacing = 4

        topValueImageView.image = R.image.iconPencil()?.tinted(with: R.color.colorIconSecondary()!)
        topValueLabel.textColor = R.color.colorTextPrimary()
        topValueLabel.font = .regularFootnote

        bottomValueLabel.textColor = R.color.colorTextSecondary()
        bottomValueLabel.font = .caption1
        bottomValueLabel.textAlignment = .right
        rowContentView.valueView.fView.iconWidth = 12
        rowContentView.valueView.fView.spacing = 6
        borderView.strokeColor = R.color.colorDivider()!
    }
}

extension StackTitleMultiValueEditCell: StackTableViewCellProtocol {}

extension StackTitleMultiValueEditCell {
    func bind(viewModel: BalanceViewModelProtocol) {
        topValueLabel.text = viewModel.amount
        bottomValueLabel.text = viewModel.price
    }

    // TODO: Skeleton
    func bind(loadableViewModel: LoadableViewModelState<BalanceViewModelProtocol>) {
        loadableViewModel.value.map(bind)
    }
}
