import Foundation
import UIKit
import SoraUI
import Kingfisher

final class StackTitleMultiValueEditCell: RowView<GenericTitleValueView<RoundedButton, GenericPairValueView<RoundedButton, UILabel>>> {
    var titleButton: RoundedButton { rowContentView.titleView }
    var valueTopButton: RoundedButton { rowContentView.valueView.fView }
    var valueBottomLabel: UILabel { rowContentView.valueView.sView }

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
        titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        titleButton.imageWithTitleView?.titleFont = .regularFootnote
        titleButton.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
        titleButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        titleButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        titleButton.applyIconStyle()
        titleButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        let iconPencil = R.image.iconPencil()?.tinted(with: R.color.colorIconSecondary()!)
        valueTopButton.applyIconStyle()
        valueTopButton.imageWithTitleView?.iconImage = iconPencil?.kf.resize(to: .init(width: 16, height: 16))
        valueTopButton.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        valueTopButton.imageWithTitleView?.titleFont = .regularFootnote
        valueTopButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 6
        valueTopButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        valueBottomLabel.textColor = R.color.colorTextSecondary()
        valueBottomLabel.font = .caption1
        valueBottomLabel.textAlignment = .right
        borderView.strokeColor = R.color.colorDivider()!

        rowContentView.valueView.makeVertical()
        hasInteractableContent = true
    }
}

extension StackTitleMultiValueEditCell: StackTableViewCellProtocol {}

extension StackTitleMultiValueEditCell {
    func bind(viewModel: BalanceViewModelProtocol) {
        valueTopButton.imageWithTitleView?.title = viewModel.amount
        valueBottomLabel.text = viewModel.price
        valueTopButton.invalidateLayout()
    }

    // TODO: Skeleton
    func bind(loadableViewModel: LoadableViewModelState<BalanceViewModelProtocol>) {
        loadableViewModel.value.map(bind)
    }
}
