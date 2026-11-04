import UIKit
import UIKit_iOS

final class SubtensorPositionSummaryView: UIView {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let captionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
    }

    let amountLabel: UILabel = .create { label in
        label.apply(style: .boldTitle2Primary)
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

    private let iconSkeletonView = SubtensorSkeletonView(cornerRadius: Constants.iconSize / 2)

    private let captionSkeletonView = SubtensorSkeletonView(cornerRadius: 6)
    private let amountSkeletonView = SubtensorSkeletonView(cornerRadius: 6)
    private let fiatSkeletonView = SubtensorSkeletonView(cornerRadius: 6)

    private let rowsView = UIView.vStack(spacing: Constants.spacing, [])
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
        case let .value(text):
            fiatLabel.text = text
            fiatLabel.isHidden = false
            fiatSkeletonView.setLoading(false)
        }

        statusView.isHidden = viewModel.isActive == nil

        if let isActive = viewModel.isActive {
            statusView.bind(status: isActive ? .active : .inactive, locale: locale)
            statusView.backgroundView.fillColor = isActive
                ? R.color.colorActiveStatusBackground()!
                : R.color.colorChipsBackground()!
        }

        bind(rows: viewModel.rows)
    }
}

private extension SubtensorPositionSummaryView {
    enum Constants {
        static let iconSize: CGFloat = 40
        static let skeletonHeight: CGFloat = 12
        static let spacing: CGFloat = 10
        static let valueLineHeight: CGFloat = 18
        static let valueLineSpacing: CGFloat = 2
        static let detailLineHeight: CGFloat = 16
        static let rowSkeletonWidth: CGFloat = 120
    }

    func bind(rows: [SubtensorPositionRowViewModel]) {
        while rowsView.arrangedSubviews.count < rows.count {
            rowsView.addArrangedSubview(SubtensorPositionSummaryRowView())
        }

        rowsView.arrangedSubviews.enumerated().forEach { index, view in
            view.isHidden = index >= rows.count

            if index < rows.count {
                (view as? SubtensorPositionSummaryRowView)?.bind(viewModel: rows[index])
            }
        }
    }

    func setupLayout() {
        let textView = UIView.vStack(alignment: .leading, spacing: 2, [captionLabel, amountLabel, fiatLabel])
        let headerView = UIView.hStack(alignment: .top, spacing: 12, [iconView, textView, UIView(), statusView])

        addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
        }

        addSubview(rowsView)
        rowsView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(Constants.spacing)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().inset(12)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        captionLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(16)
        }

        fiatLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(18)
        }

        amountLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(28)
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

        let skeletons: [(SubtensorSkeletonView, UILabel, CGFloat)] = [
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

    let captionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.numberOfLines = 0
    }

    let skeletonView = SubtensorSkeletonView(cornerRadius: 6)

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
        case let .loaded(value, detail):
            valueLabel.text = value
            valueLabel.textColor = viewModel.tone.textColor
            detailLabel.text = detail
            detailLabel.isHidden = detail == nil
            skeletonView.setLoading(false)
        }

        captionLabel.text = viewModel.caption
        captionLabel.isHidden = viewModel.caption == nil
    }

    private func setupLayout() {
        let dividerView: UIView = .create { view in
            view.backgroundColor = R.color.colorDivider()
        }

        addSubview(dividerView)
        dividerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(SubtensorDividerStyle.thickness)
        }

        let valueView = UIView.vStack(
            alignment: .trailing,
            spacing: SubtensorPositionSummaryView.Constants.valueLineSpacing,
            [valueLabel, detailLabel]
        )
        let contentView = UIView.hStack(alignment: .center, spacing: 12, [titleLabel, UIView(), valueView])
        let stackView = UIView.vStack(spacing: 8, [contentView, captionLabel])

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom).offset(SubtensorPositionSummaryView.Constants.spacing)
            make.leading.trailing.bottom.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(
                SubtensorPositionSummaryView.Constants.valueLineHeight +
                    SubtensorPositionSummaryView.Constants.valueLineSpacing +
                    SubtensorPositionSummaryView.Constants.detailLineHeight
            )
        }

        addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.trailing.centerY.equalTo(contentView)
            make.width.equalTo(SubtensorPositionSummaryView.Constants.rowSkeletonWidth)
            make.height.equalTo(SubtensorPositionSummaryView.Constants.skeletonHeight)
        }

        valueLabel.snp.makeConstraints { make in
            make.height.equalTo(SubtensorPositionSummaryView.Constants.valueLineHeight)
        }

        detailLabel.snp.makeConstraints { make in
            make.height.equalTo(SubtensorPositionSummaryView.Constants.detailLineHeight)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
