import UIKit
import UIKit_iOS

final class SubtensorPositionSummaryView: UIView {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let captionLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let amountLabel: UILabel = .create { label in
        label.apply(style: .boldTitle1Primary)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
    }

    let fiatLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let statusView: StakingStatusView = .create { view in
        view.backgroundView.apply(style: .chips)
        view.isUserInteractionEnabled = false
    }

    let rowsStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = 0
    }

    private let iconSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = Constants.iconSize / 2
    }

    private let captionSkeletonView = SubtensorPositionSummaryView.createSkeleton()
    private let amountSkeletonView = SubtensorPositionSummaryView.createSkeleton()
    private let fiatSkeletonView = SubtensorPositionSummaryView.createSkeleton()

    private var rowViews: [SubtensorPositionSummaryRowView] = []
    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPositionSummaryViewModel, locale: Locale) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.icon
        iconView.image = nil
        viewModel.icon?.loadImage(
            on: iconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: false
        )
        iconSkeletonView.setLoading(viewModel.icon == nil)

        captionLabel.text = viewModel.caption
        captionSkeletonView.setLoading(viewModel.caption == nil)

        amountLabel.text = viewModel.amount
        amountSkeletonView.setLoading(viewModel.amount == nil)

        switch viewModel.fiat {
        case .loading:
            fiatLabel.text = nil
            fiatLabel.isHidden = false
            fiatSkeletonView.setLoading(true)
        case .hidden:
            fiatLabel.text = nil
            fiatLabel.isHidden = true
            fiatSkeletonView.setLoading(false)
        case let .loaded(text):
            fiatLabel.text = text
            fiatLabel.isHidden = false
            fiatSkeletonView.setLoading(false)
        }

        statusView.isHidden = viewModel.isActive == nil

        if let isActive = viewModel.isActive {
            statusView.bind(status: isActive ? .active : .inactive, locale: locale)
        }

        bind(rows: viewModel.rows)
    }
}

private extension SubtensorPositionSummaryView {
    enum Constants {
        static let iconSize: CGFloat = 40
        static let skeletonHeight: CGFloat = 12
    }

    static func createSkeleton() -> SubtensorChartLoadingView {
        .create { view in
            view.layer.cornerRadius = 6
        }
    }

    func bind(rows: [SubtensorPositionRowViewModel]) {
        while rowViews.count < rows.count {
            let rowView = SubtensorPositionSummaryRowView()
            rowsStackView.addArrangedSubview(rowView)
            rowViews.append(rowView)
        }

        for (index, rowView) in rowViews.enumerated() {
            rowView.isHidden = index >= rows.count

            if index < rows.count {
                rowView.bind(viewModel: rows[index])
            }
        }
    }

    func setupLayout() {
        let textView = UIView.vStack(alignment: .leading, spacing: 4, [captionLabel, amountLabel, fiatLabel])
        let headerView = UIView.hStack(alignment: .top, spacing: 12, [iconView, textView, UIView(), statusView])

        addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        addSubview(rowsStackView)
        rowsStackView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(4)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        [captionLabel, fiatLabel].forEach { label in
            label.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(18)
            }
        }

        amountLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(32)
        }

        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusView.setContentCompressionResistancePriority(.required, for: .horizontal)

        setupSkeletons()
    }

    func setupSkeletons() {
        addSubview(iconSkeletonView)
        iconSkeletonView.snp.makeConstraints { make in
            make.edges.equalTo(iconView)
        }

        let skeletons: [(SubtensorChartLoadingView, UILabel, CGFloat)] = [
            (captionSkeletonView, captionLabel, 80),
            (amountSkeletonView, amountLabel, 140),
            (fiatSkeletonView, fiatLabel, 60)
        ]

        for (skeletonView, label, width) in skeletons {
            addSubview(skeletonView)
            skeletonView.snp.makeConstraints { make in
                make.leading.centerY.equalTo(label)
                make.width.equalTo(width)
                make.height.equalTo(Constants.skeletonHeight)
            }
        }
    }
}

private final class SubtensorPositionSummaryRowView: UIView {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let valueLabel: UILabel = .create { label in
        label.apply(style: .semiboldFootnotePrimary)
        label.textAlignment = .right
    }

    let detailLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .right
    }

    let skeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPositionRowViewModel) {
        titleLabel.text = viewModel.title

        switch viewModel.value {
        case .loading:
            valueLabel.text = nil
            detailLabel.text = nil
            detailLabel.isHidden = true
            skeletonView.setLoading(true)
        case let .loaded(value, detail, isPositive):
            valueLabel.text = value
            valueLabel.textColor = isPositive ? R.color.colorTextPositive() : R.color.colorTextPrimary()
            detailLabel.text = detail
            detailLabel.isHidden = detail == nil
            skeletonView.setLoading(false)
        }
    }

    private func setupLayout() {
        let dividerView: UIView = .create { view in
            view.backgroundColor = R.color.colorDivider()
        }

        addSubview(dividerView)
        dividerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }

        let valueView = UIView.vStack(alignment: .trailing, spacing: 2, [valueLabel, detailLabel])
        let contentView = UIView.hStack(alignment: .center, spacing: 12, [titleLabel, UIView(), valueView])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(12)
            make.height.greaterThanOrEqualTo(24)
        }

        addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.trailing.centerY.equalTo(contentView)
            make.width.equalTo(100)
            make.height.equalTo(12)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
