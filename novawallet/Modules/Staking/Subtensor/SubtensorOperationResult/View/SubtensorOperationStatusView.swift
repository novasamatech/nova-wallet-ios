import UIKit
import UIKit_iOS
import SnapKit

final class SubtensorOperationStatusView: UIView {
    let progressView = OperationExecutionProgressView()

    let pendingView: UIImageView = .create { view in
        view.image = R.image.iconPending()
        view.contentMode = .scaleAspectFit
    }

    let statusTitleView: MultiValueView = .create { view in
        view.valueTop.textAlignment = .center
        view.valueBottom.textAlignment = .center
        view.spacing = 4
    }

    let pillBackgroundView: RoundedView = .create { view in
        view.cornerRadius = 12
    }

    let pillIconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let pillLabel: ShimmerLabel = .create { label in
        label.numberOfLines = 0
    }

    private var pillLabelIconConstraint: Constraint?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorResultStatusViewModel) {
        bindIcon(for: viewModel)

        statusTitleView.bind(topValue: viewModel.title, bottomValue: viewModel.subtitle)
        pillLabel.text = viewModel.details

        applyStyle(for: viewModel.status)
    }

    func updateProgress(remainedTime: UInt) {
        progressView.updateProgress(remainedTime: remainedTime)
    }

    func updateAnimationOnAppear() {
        progressView.updateAnimationOnAppear()
    }
}

private extension SubtensorOperationStatusView {
    func bindIcon(for viewModel: SubtensorResultStatusViewModel) {
        progressView.isHidden = viewModel.status == .pending
        pendingView.isHidden = viewModel.status != .pending

        switch viewModel.status {
        case .progress:
            if let countdown = viewModel.countdown {
                progressView.bind(viewModel: .inProgress(countdown))
            }
        case .done:
            progressView.bind(viewModel: .completed)
        case .failed:
            progressView.bind(viewModel: .failed)
        case .pending:
            break
        }
    }

    func applyStyle(for status: SubtensorResultStatus) {
        let topStyle: UILabel.Style = switch status {
        case .progress, .pending:
            .boldTitle1Primary
        case .done:
            .boldTitle1Positive
        case .failed:
            .boldTitle1Negative
        }

        let bottomStyle: UILabel.Style = status == .progress ? .semiboldBodyButtonAccent : .semiboldBodySecondary

        statusTitleView.apply(style: .init(topLabel: topStyle, bottomLabel: bottomStyle))

        if status == .failed {
            pillBackgroundView.applyErrorBlockBackgroundStyle()
            pillIconView.image = R.image.iconErrorFilled()?.withRenderingMode(.alwaysTemplate)
            pillIconView.tintColor = R.color.colorIconNegative()
            pillLabel.applyShimmer(style: .regularSubheadlinePrimary)
            pillLabel.apply(style: .regularSubhedlinePrimary)
        } else {
            pillBackgroundView.applyCellBackgroundStyle()
            pillIconView.image = R.image.iconRoute()?.withRenderingMode(.alwaysTemplate)
            pillIconView.tintColor = R.color.colorIconSecondary()
            pillLabel.applyShimmer(style: .regularSubheadlineSecondary)
            pillLabel.apply(style: .regularSubhedlineSecondary)
        }

        pillBackgroundView.cornerRadius = 12
        pillLabel.textAlignment = status == .failed ? .left : .center

        let hasIcon = status != .pending
        pillIconView.isHidden = !hasIcon

        if hasIcon {
            pillLabelIconConstraint?.activate()
        } else {
            pillLabelIconConstraint?.deactivate()
        }

        if status == .progress {
            pillLabel.startShimmering()
        } else {
            pillLabel.stopShimmering()
        }
    }

    func setupLayout() {
        let iconContainer = UIView()
        iconContainer.addSubview(progressView)
        iconContainer.addSubview(pendingView)

        progressView.snp.makeConstraints { make in
            make.top.bottom.centerX.equalToSuperview()
        }

        pendingView.snp.makeConstraints { make in
            make.center.equalTo(progressView)
            make.size.equalTo(progressView.preferredSize)
        }

        pillBackgroundView.addSubview(pillIconView)
        pillIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        pillBackgroundView.addSubview(pillLabel)
        pillLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(14)
            make.centerX.equalToSuperview().priority(.high)
            make.leading.greaterThanOrEqualToSuperview().inset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            pillLabelIconConstraint = make.leading.greaterThanOrEqualTo(pillIconView.snp.trailing).constraint
        }

        let contentView = UIView.vStack(alignment: .fill, [iconContainer, statusTitleView, pillBackgroundView])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.setCustomSpacing(16, after: iconContainer)
        contentView.setCustomSpacing(24, after: statusTitleView)

        pillBackgroundView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(48)
        }
    }
}
