import UIKit

typealias TitleValueDiffView = GenericTitleValueView<
    IconDetailsView,
    GenericPairValueView<GenericPairValueView<IconDetailsView, UILabel>, IconDetailsView>
>

extension TitleValueDiffView: BindableView {
    typealias TModel = ReferendumLockTransitionViewModel

    func bind(viewModel: ReferendumLockTransitionViewModel) {
        let viewTop = valueView.fView
        viewTop.fView.detailsLabel.text = viewModel.fromValue
        viewTop.sView.text = viewModel.toValue

        let viewBottom = valueView.sView

        if let change = viewModel.change {
            viewBottom.isHidden = false

            viewBottom.detailsLabel.text = change.value

            let icon = change.isIncrease ? R.image.iconAmountInc() : R.image.iconAmountDec()
            viewBottom.imageView.image = icon
        } else {
            viewBottom.isHidden = true
        }

        setNeedsLayout()
    }

    func applyDefaultStyle() {
        titleView.spacing = 8.0
        titleView.mode = .iconDetails
        titleView.iconWidth = 16.0
        titleView.detailsLabel.textColor = R.color.colorTextSecondary()
        titleView.detailsLabel.font = .regularFootnote
        titleView.detailsLabel.numberOfLines = 1

        valueView.setVerticalAndSpacing(0.0)
        valueView.stackView.alignment = .trailing

        let mappingView = valueView.fView
        mappingView.setHorizontalAndSpacing(4.0)
        mappingView.fView.iconWidth = 12.0
        mappingView.fView.spacing = 4.0
        mappingView.fView.mode = .detailsIcon
        mappingView.fView.detailsLabel.textColor = R.color.colorTextSecondary()
        mappingView.fView.detailsLabel.font = .regularFootnote
        mappingView.fView.detailsLabel.numberOfLines = 1
        mappingView.fView.imageView.image = R.image.iconGovLockTransition()
        mappingView.sView.textColor = R.color.colorTextPrimary()
        mappingView.sView.font = .regularFootnote

        let changesView = valueView.sView
        changesView.mode = .iconDetails
        changesView.spacing = 0.0
        changesView.detailsLabel.textColor = R.color.colorButtonTextAccent()
        changesView.detailsLabel.font = .caption1
        changesView.detailsLabel.numberOfLines = 1
    }
}
