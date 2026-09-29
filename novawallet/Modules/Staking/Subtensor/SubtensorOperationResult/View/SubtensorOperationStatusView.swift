import UIKit
import UIKit_iOS

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
        view.image = R.image.iconErrorFilled()
        view.contentMode = .scaleAspectFit
    }

    let pillLabel: ShimmerLabel = .create { label in
        label.textAlignment = .center
        label.numberOfLines = 0
    }

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
        pillIconView.isHidden = viewModel.status != .failed

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
            pillLabel.applyShimmer(style: .regularSubheadlinePrimary)
            pillLabel.apply(style: .regularSubhedlinePrimary)
        } else {
            pillBackgroundView.applyCellBackgroundStyle()
            pillLabel.applyShimmer(style: .regularSubheadlineSecondary)
            pillLabel.apply(style: .regularSubhedlineSecondary)
        }

        pillBackgroundView.cornerRadius = 12

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

        let pillContent = UIView.hStack(alignment: .center, spacing: 8, [pillIconView, pillLabel])

        pillIconView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        pillBackgroundView.addSubview(pillContent)
        pillContent.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(14)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
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
