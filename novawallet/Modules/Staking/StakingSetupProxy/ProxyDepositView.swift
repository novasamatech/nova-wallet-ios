import SoraUI

final class ProxyDepositView: RowView<LoadableGenericIconDetailsView<NetworkFeeInfoView>> {
    var imageView: UIImageView { rowContentView.imageView }
    var titleButton: RoundedButton { rowContentView.detailsView.titleButton }
    var valueTopButton: RoundedButton { rowContentView.detailsView.titleButton }
    var valueBottomLabel: UILabel { rowContentView.detailsView.valueBottomLabel }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureStyle() {
        preferredHeight = 44
        roundedBackgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        borderView.borderType = .none
    }
}
