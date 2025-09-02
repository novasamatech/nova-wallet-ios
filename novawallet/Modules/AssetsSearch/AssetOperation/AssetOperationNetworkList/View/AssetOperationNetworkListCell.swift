import UIKit
import UIKit_iOS

class AssetOperationNetworkListCell: PlainBaseTableViewCell<AssetOperationNetworkView> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }
}

class AssetOperationNetworkView: UIView {
    let contentView: GenericBorderedView<
        GenericPairValueView<
            GenericPairValueView<
                UIImageView,
                UILabel
            >,
            MultiValueView
        >
    > = .create { view in
        view.contentView.makeHorizontal()

        view.contentView.fView.setHorizontalAndSpacing(12)
        view.contentView.fView.fView.contentMode = .scaleAspectFit
        view.contentView.fView.sView.apply(style: .regularSubhedlinePrimary)

        view.contentView.sView.valueTop.apply(style: .semiboldCalloutPrimary)
        view.contentView.sView.valueBottom.apply(style: .caption1Secondary)
        view.contentView.sView.spacing = 2.0

        view.backgroundView.fillColor = R.color.colorChipsBackground()!
        view.contentInsets = Constants.contentInsets
        view.backgroundView.cornerRadius = Constants.backgrounViewCornerRadius
    }

    var imageView: UIImageView {
        contentView.contentView.fView.fView
    }

    var titleLabel: UILabel {
        contentView.contentView.fView.sView
    }

    var amountLabel: UILabel {
        contentView.contentView.sView.valueTop
    }

    var valueLabel: UILabel {
        contentView.contentView.sView.valueBottom
    }

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetOperationNetworkViewModel) {
        amountLabel.text = viewModel.amount
        valueLabel.text = viewModel.value
        titleLabel.text = viewModel.chainAsset.networkViewModel.name

        viewModel.chainAsset.networkViewModel.icon?.loadImage(
            on: imageView,
            targetSize: CGSize(
                width: Constants.networkIconSize,
                height: Constants.networkIconSize
            ),
            animated: true
        )
    }
}

// MARK: Private

private extension AssetOperationNetworkView {
    func setupLayout() {
        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.networkIconSize)
        }
    }
}

// MARK: Constants

private extension AssetOperationNetworkView {
    private enum Constants {
        static let networkIconSize: CGFloat = 28.0
        static let contentInsets: UIEdgeInsets = .init(
            top: 9.5,
            left: 16,
            bottom: 9.5,
            right: 16
        )
        static let backgrounViewCornerRadius: CGFloat = 12.0
    }
}
