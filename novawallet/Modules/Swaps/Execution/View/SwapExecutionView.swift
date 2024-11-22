import UIKit

final class SwapExecutionView: UIView {
    let progressView = OperationExecutionProgressView()

    let statusTitleView: MultiValueView = .create { view in
        view.apply(
            style: .init(
                topLabel: .boldTitle1Primary,
                bottomLabel: .semiboldBodyButtonAccent
            )
        )

        view.valueTop.textAlignment = .center
        view.valueBottom.textAlignment = .center

        view.spacing = 4
    }

    let statusDetailsView: GenericBorderedView<UILabel> = .create { view in
        view.contentInsets = UIEdgeInsets(verticalInset: 0, horizontalInset: 16)
        view.contentView.textAlignment = .center
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

            statusDetailsView.contentView.text = completed.details

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

            statusDetailsView.contentView.text = failed.details
        }
    }

    private func setupLayout() {
        let contentView = UIView.hStack(
            alignment: .center,
            [progressView, statusTitleView, statusDetailsView]
        )

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.setCustomSpacing(16, after: progressView)
        contentView.setCustomSpacing(24, after: statusTitleView)
    }
}
