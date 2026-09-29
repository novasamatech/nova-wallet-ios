import UIKit
import UIKit_iOS

final class SubtensorSubnetEstimateView: UIView {
    let chipButtons: [TriangularedButton] = (0 ..< 4).map { index in
        let button = TriangularedButton()
        button.tag = index
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        button.applySecondaryEnabledStyle()
        return button
    }

    let holdLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
        label.numberOfLines = 0
    }

    let earningsTitleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let earningsValueLabel: UILabel = .create { label in
        label.apply(style: .footnotePositive)
        label.numberOfLines = 0
    }

    let earningsSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    let noteLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.numberOfLines = 0
    }

    private lazy var earningsView = UIView.hStack(
        alignment: .firstBaseline,
        spacing: 4,
        [earningsTitleLabel, earningsValueLabel, UIView()]
    )

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

    func bind(viewModel: SubtensorSubnetEstimateViewModel) {
        zip(chipButtons, viewModel.chips).enumerated().forEach { index, pair in
            let (button, title) = pair
            let isMax = index == viewModel.chips.count - 1
            let isEnabled = !isMax || viewModel.isMaxEnabled

            if !isEnabled {
                button.applyDisabledStyle()
            } else if index == viewModel.selectedChipIndex {
                button.applyEnabledStyle()
            } else {
                button.applySecondaryEnabledStyle()
            }

            button.isEnabled = isEnabled
            button.imageWithTitleView?.title = title
            button.invalidateLayout()
        }

        holdLabel.text = viewModel.hold
        holdLabel.isHidden = viewModel.hold == nil

        switch viewModel.earnings {
        case .loading:
            earningsView.isHidden = false
            earningsValueLabel.text = nil
            earningsSkeletonView.setLoading(true)
        case .hidden:
            earningsView.isHidden = true
            earningsSkeletonView.setLoading(false)
        case let .value(text):
            earningsView.isHidden = false
            earningsValueLabel.text = text
            earningsSkeletonView.setLoading(false)
        }
    }
}

private extension SubtensorSubnetEstimateView {
    func setupLayout() {
        let chipsView = UIView.hStack(distribution: .fillEqually, spacing: 8, chipButtons)

        chipsView.snp.makeConstraints { make in
            make.height.equalTo(36)
        }

        let contentView = UIView.vStack(spacing: 8, [chipsView, holdLabel, earningsView, noteLabel])
        contentView.setCustomSpacing(16, after: chipsView)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16))
        }

        earningsTitleLabel.setContentHuggingPriority(.required, for: .horizontal)
        earningsTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        earningsView.addSubview(earningsSkeletonView)
        earningsSkeletonView.snp.makeConstraints { make in
            make.leading.equalTo(earningsTitleLabel.snp.trailing).offset(8)
            make.centerY.equalTo(earningsTitleLabel)
            make.size.equalTo(CGSize(width: 100, height: 12))
        }
    }
}
