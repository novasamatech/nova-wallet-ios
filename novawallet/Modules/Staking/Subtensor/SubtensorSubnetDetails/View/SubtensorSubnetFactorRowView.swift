import UIKit

final class SubtensorSubnetFactorRowView: RowView<GenericTitleValueView<MultiValueView, IconDetailsView>> {
    var titleLabel: UILabel { rowContentView.titleView.valueTop }

    var captionLabel: UILabel { rowContentView.titleView.valueBottom }

    var valueLabel: UILabel { rowContentView.valueView.detailsLabel }

    var markView: UIImageView { rowContentView.valueView.imageView }

    let skeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorSubnetFactorRowViewModel) {
        titleLabel.text = viewModel.title
        captionLabel.text = viewModel.caption

        switch viewModel.value {
        case .loading:
            bind(value: nil, color: R.color.colorTextSecondary(), mark: nil)
            skeletonView.setLoading(true)
        case let .safer(text):
            bind(
                value: text,
                color: R.color.colorTextPositive(),
                mark: R.image.iconCheckmark()?.tinted(with: R.color.colorIconPositive()!)
            )
        case let .riskier(text):
            bind(
                value: text,
                color: R.color.colorTextWarning(),
                mark: R.image.iconWarning()?.tinted(with: R.color.colorIconWarning()!)
            )
        case let .unknown(text):
            bind(value: text, color: R.color.colorTextSecondary(), mark: nil)
        }
    }
}

private extension SubtensorSubnetFactorRowView {
    func bind(value: String?, color: UIColor?, mark: UIImage?) {
        skeletonView.setLoading(false)

        valueLabel.text = value
        valueLabel.textColor = color
        markView.image = mark
        markView.isHidden = mark == nil
    }

    func configure() {
        isUserInteractionEnabled = false
        borderView.strokeColor = R.color.colorDivider()!

        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.textAlignment = .left
        captionLabel.apply(style: .caption1Secondary)
        captionLabel.textAlignment = .left
        rowContentView.titleView.spacing = 2

        let valueView = rowContentView.valueView
        valueView.mode = .detailsIcon
        valueView.spacing = 4
        valueView.iconWidth = 16
        valueLabel.font = .semiBoldFootnote
        valueLabel.textAlignment = .right

        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 72, height: 12))
        }
    }
}

extension SubtensorSubnetFactorRowView: StackTableViewCellProtocol {}
