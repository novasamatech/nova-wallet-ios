import UIKit

final class SwapExecutionView: UIView {
    let progressView = OperationExecutionProgressView()

    let resultTileView = SwapExecutionResultTileView()

    let titleLabel: UILabel = .create {
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    let amountLabel: UILabel = .create {
        $0.apply(style: .boldLargePrimary)
        $0.textAlignment = .center
        $0.numberOfLines = 1
        $0.adjustsFontSizeToFitWidth = true
        $0.minimumScaleFactor = Constants.amountMinimumScale
    }

    let detailsLabel: UILabel = .create {
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    let operationsView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
        $0.layer.cornerRadius = Constants.operationsCornerRadius
        $0.layer.borderWidth = Constants.operationsBorderWidth
        $0.layer.borderColor = R.color.colorContainerBorder()?.cgColor
    }

    let operationsLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private lazy var progressContainer = UIView.vStack(alignment: .center, [progressView])
    private lazy var resultTileContainer = UIView.vStack(alignment: .center, [resultTileView])

    private lazy var stackView = UIView.vStack(
        alignment: .fill,
        [progressContainer, resultTileContainer, titleLabel, amountLabel, detailsLabel, operationsView]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }

        operationsView.addSubview(operationsLabel)
        operationsLabel.snp.makeConstraints { $0.edges.equalToSuperview().inset(Constants.operationsInsets) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SwapExecutionViewModel, locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch viewModel {
        case let .inProgress(inProgress):
            progressView.bind(viewModel: .inProgress(inProgress.remainedTimeViewModel))

            applyInProgressLayout()

            titleLabel.text = strings.swapsExecutionDontCloseApp()
            detailsLabel.text = inProgress.currentOperation
            operationsLabel.text = inProgress.details
        case let .completed(completed):
            applyFinishedLayout(isSuccess: true)

            titleLabel.text = strings.transactionStatusCompleted()
            amountLabel.text = completed.amount
            detailsLabel.text = completed.time
        case let .failed(failed):
            applyFinishedLayout(isSuccess: false)

            titleLabel.text = strings.transactionStatusFailed()
            detailsLabel.text = failed.time
        }
    }

    func updateProgress(remainedTime: UInt) {
        progressView.updateProgress(remainedTime: remainedTime)
    }

    func updateAnimationOnAppear() {
        progressView.updateAnimationOnAppear()
    }
}

private extension SwapExecutionView {
    func applyInProgressLayout() {
        progressContainer.isHidden = false
        resultTileContainer.isHidden = true
        amountLabel.isHidden = true
        operationsView.isHidden = false

        titleLabel.apply(style: .boldTitle2Primary)
        detailsLabel.apply(style: .semiboldSubheadlineAccent)

        stackView.setCustomSpacing(Constants.inProgressIconSpacing, after: progressContainer)
        stackView.setCustomSpacing(Constants.inProgressTitleSpacing, after: titleLabel)
        stackView.setCustomSpacing(Constants.inProgressDetailsSpacing, after: detailsLabel)
    }

    func applyFinishedLayout(isSuccess: Bool) {
        progressContainer.isHidden = true
        resultTileContainer.isHidden = false
        amountLabel.isHidden = !isSuccess
        operationsView.isHidden = true

        progressView.bind(viewModel: isSuccess ? .completed : .failed)
        resultTileView.bind(isSuccess: isSuccess)

        titleLabel.apply(style: isSuccess ? .swapExecutionSuccessTitle : .swapExecutionFailureTitle)
        detailsLabel.apply(style: .footnoteSecondary)

        stackView.setCustomSpacing(Constants.finishedIconSpacing, after: resultTileContainer)
        stackView.setCustomSpacing(
            isSuccess ? Constants.completedTitleSpacing : Constants.failedTitleSpacing,
            after: titleLabel
        )
        stackView.setCustomSpacing(Constants.completedAmountSpacing, after: amountLabel)
    }
}

private extension UILabel.Style {
    static let swapExecutionSuccessTitle = UILabel.Style(
        textColor: R.color.colorTextPositive()!,
        font: .boldTitle2
    )

    static let swapExecutionFailureTitle = UILabel.Style(
        textColor: R.color.colorTextNegative()!,
        font: .boldTitle2
    )
}

extension SwapExecutionView {
    enum Constants {
        static let amountMinimumScale: CGFloat = 0.5
        static let operationsInsets = UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 16)
        static let operationsCornerRadius: CGFloat = 12
        static let operationsBorderWidth: CGFloat = 1
        static let inProgressIconSpacing: CGFloat = 10
        static let inProgressTitleSpacing: CGFloat = 10
        static let inProgressDetailsSpacing: CGFloat = 10
        static let finishedIconSpacing: CGFloat = 6
        static let completedTitleSpacing: CGFloat = 3
        static let failedTitleSpacing: CGFloat = 6
        static let completedAmountSpacing: CGFloat = 2
    }
}
