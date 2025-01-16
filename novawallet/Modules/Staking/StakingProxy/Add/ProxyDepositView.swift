import UIKit_iOS

final class ProxyDepositView: RowView<IconDetailsGenericView<NetworkFeeInfoView>>, StackTableViewCellProtocol {
    var imageView: UIImageView { rowContentView.imageView }
    var titleButton: RoundedButton { rowContentView.detailsView.titleButton }
    var valueTopButton: RoundedButton { rowContentView.detailsView.valueTopButton }
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

    func bind(loadableViewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rowContentView.detailsView.bind(loadableViewModel: loadableViewModel)
    }
}
