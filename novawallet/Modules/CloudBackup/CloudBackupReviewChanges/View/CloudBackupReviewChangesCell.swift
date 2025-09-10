import Foundation

final class CloudBackupReviewChangesCell: CollectionViewContainerCell<
    GenericTitleValueView<SingleTitleWalletView, IconDetailsView>
> {
    var walletView: SingleTitleWalletView {
        view.titleView
    }

    var statusView: IconDetailsView {
        view.valueView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        statusView.mode = .iconDetails
        statusView.iconWidth = 16
        statusView.spacing = 4
        statusView.detailsLabel.apply(style: .footnoteSecondary)
    }

    private func apply(changeType: CloudBackupReviewItemViewModel.ChangeType, locale: Locale) {
        switch changeType {
        case .new:
            statusView.imageView.image = nil
            statusView.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonNew()
            statusView.detailsLabel.textColor = R.color.colorTextSecondary()
        case .modified:
            statusView.imageView.image = R.image.iconWarning()
            statusView.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonModified()
            statusView.detailsLabel.textColor = R.color.colorTextWarning()
        case .removed:
            statusView.imageView.image = R.image.iconErrorFilled()
            statusView.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonRemoved()
            statusView.detailsLabel.textColor = R.color.colorTextNegative()
        }
    }

    func bind(viewModel: CloudBackupReviewItemViewModel, locale: Locale) {
        walletView.bind(viewModel: .init(wallet: viewModel.walletViewModel, type: .noInfo))

        apply(changeType: viewModel.changeType, locale: locale)
    }
}
