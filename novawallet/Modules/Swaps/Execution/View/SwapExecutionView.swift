import UIKit

final class SwapExecutionView: UIView {
    let progressView = OperationExecutionProgressView()

    let statusTitleView: MultiValueView = .create { view in
        view.valueTop.textAlignment = .center
        view.valueBottom.textAlignment = .center

        view.spacing = 4
    }

    let statusDetailsView: GenericBorderedView<ShimmerLabel> = .create { view in
        view.contentInsets = UIEdgeInsets(verticalInset: 0, horizontalInset: 16)
        view.contentView.textAlignment = .center
        view.backgroundView.cornerRadius = 12
        view.contentView.numberOfLines = 0
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

    func bind(viewModel: SwapExecutionViewModel, locale: Locale) {
        switch viewModel {
        case let .inProgress(inProgress):
            progressView.bind(viewModel: .inProgress(inProgress.remainedTimeViewModel))

            statusTitleView.bind(
                viewModel: .init(
                    topValue: R.string.localizable.swapsExecutionDontCloseApp(
                        preferredLanguages: locale.rLanguages
                    ),
                    bottomValue: inProgress.currentOperation
                )
            )

            statusDetailsView.contentView.text = inProgress.details

            applyInProgressStyle()

            statusDetailsView.contentView.startShimmering()

        case let .completed(completed):
            progressView.bind(viewModel: .completed)

            statusTitleView.bind(
                viewModel: .init(
                    topValue: R.string.localizable.transactionStatusCompleted(
                        preferredLanguages: locale.rLanguages
                    ),
                    bottomValue: completed.time
                )
            )

            statusDetailsView.contentView.stopShimmering()
            statusDetailsView.contentView.text = completed.details

            applyCompletedStyle()

        case let .failed(failed):
            progressView.bind(viewModel: .failed)

            statusTitleView.bind(
                viewModel: .init(
                    topValue: R.string.localizable.transactionStatusFailed(
                        preferredLanguages: locale.rLanguages
                    ),
                    bottomValue: failed.time
                )
            )

            statusDetailsView.contentView.stopShimmering()
            statusDetailsView.contentView.text = failed.details

            applyFailedStyle()
        }
    }

    func updateProgress(remainedTime: UInt) {
        progressView.updateProgress(remainedTime: remainedTime)
    }

    func updateAnimationOnAppear() {
        progressView.updateAnimationOnAppear()
    }

    private func applyInProgressStyle() {
        statusTitleView.apply(
            style: .init(
                topLabel: .boldTitle1Primary,
                bottomLabel: .semiboldBodyButtonAccent
            )
        )

        statusDetailsView.backgroundView.applyCellBackgroundStyle()
        statusDetailsView.contentView.applyShimmer(style: .regularSubheadlineSecondary)
        statusDetailsView.contentView.apply(style: .regularSubhedlineSecondary)
    }

    private func applyFailedStyle() {
        statusTitleView.apply(
            style: .init(
                topLabel: .boldTitle1Negative,
                bottomLabel: .semiboldBodySecondary
            )
        )

        statusDetailsView.backgroundView.applyErrorBlockBackgroundStyle()
        statusDetailsView.contentView.applyShimmer(style: .regularSubheadlinePrimary)
        statusDetailsView.contentView.apply(style: .regularSubhedlinePrimary)
    }

    private func applyCompletedStyle() {
        statusTitleView.apply(
            style: .init(
                topLabel: .boldTitle1Positive,
                bottomLabel: .semiboldBodySecondary
            )
        )

        statusDetailsView.backgroundView.applyCellBackgroundStyle()
        statusDetailsView.contentView.applyShimmer(style: .regularSubheadlineSecondary)
        statusDetailsView.contentView.apply(style: .regularSubhedlineSecondary)
    }

    private func setupLayout() {
        let progressViewContainer = UIView.vStack(alignment: .center, [progressView])

        let contentView = UIView.vStack(
            alignment: .fill,
            [
                progressViewContainer,
                statusTitleView,
                statusDetailsView
            ]
        )

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.setCustomSpacing(16, after: progressViewContainer)
        contentView.setCustomSpacing(24, after: statusTitleView)

        statusDetailsView.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }
}
