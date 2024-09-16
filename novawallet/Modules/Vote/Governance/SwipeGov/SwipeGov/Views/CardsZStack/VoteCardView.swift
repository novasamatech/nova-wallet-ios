import SnapKit
import UIKit
import SoraUI

final class VoteCardView: RoundedView {
    private let gradientView: RoundedGradientBackgroundView = .create { view in
        view.applyCellBackgroundStyle()
    }

    private var summaryLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.numberOfLines = 0
        view.textAlignment = .left
    }

    var skeletonView: SkrullableView?

    private lazy var requestedView: GenericPairValueView<
        MultiValueView,
        UILabel
    > = .create { view in
        view.setVerticalAndSpacing(Constants.requestedViewInnerSpacing)
        view.fView.spacing = Constants.requestedViewInnerSpacing

        view.fView.stackView.alignment = .leading
        view.fView.valueTop.apply(style: .footnoteSecondary)

        view.fView.valueTop.text = R.string.localizable.voteCardRequested(
            preferredLanguages: viewModel?.locale.rLanguages
        )

        view.fView.valueBottom.apply(style: .title3Primary)
        view.sView.apply(style: .caption1Secondary)
    }

    private var assetAmountLabel: UILabel {
        requestedView.fView.valueBottom
    }

    private var fiatAmountLabel: UILabel {
        requestedView.sView
    }

    private lazy var readMoreButton: LoadableActionView = .create { view in
        view.actionButton.applyEnabledStyle(colored: R.color.colorButtonBackgroundSecondary()!)
        view.actionButton.imageWithTitleView?.title = R.string.localizable.commonReadMore(
            preferredLanguages: viewModel?.locale.rLanguages
        )
    }

    private(set) var viewModel: VoteCardViewModel?

    private var loadingState: LoadingState = .none {
        didSet {
            if loadingState == .none {
                stopLoadingIfNeeded()
            } else {
                startLoadingIfNeeded()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if loadingState != .none {
            updateLoadingState()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var cornerRadius: CGFloat {
        didSet {
            super.cornerRadius = cornerRadius
            gradientView.cornerRadius = cornerRadius
        }
    }

    func bind(with viewModel: VoteCardViewModel) {
        self.viewModel = viewModel

        viewModel.view = self
        viewModel.onSetup()
    }

    func setupAction() {
        readMoreButton.actionButton.addTarget(
            self,
            action: #selector(actionReadMore),
            for: .touchUpInside
        )
    }

    @objc func actionReadMore() {
        viewModel?.onActionReadMore()
    }
}

// MARK: CardStackable

extension VoteCardView: CardStackable {
    func didBecomeTopView() {
        viewModel?.onBecomeTopView()
    }

    func didAddToStack() {
        viewModel?.onAddToStack()
    }

    func didPopFromStack(direction: CardsZStack.DismissalDirection) {
        viewModel?.onPop(direction: direction)
    }

    func prepareForReuse() {
        transform = .identity
        summaryLabel.text = nil
        assetAmountLabel.text = nil
        fiatAmountLabel.text = nil
        requestedView.isHidden = false
        viewModel = nil
    }
}

// MARK: StackCardViewUpdatable

extension VoteCardView: StackCardViewUpdatable {
    func setSummary(loadingState: LoadableViewModelState<String>) {
        switch loadingState {
        case .loading:
            self.loadingState.formUnion(.summary)
        case let .cached(value), let .loaded(value):
            self.loadingState.remove(.summary)
            summaryLabel.text = value
        }
    }

    func setRequestedAmount(loadingState: LoadableViewModelState<BalanceViewModelProtocol?>) {
        switch loadingState {
        case .loading:
            self.loadingState.formUnion(.amount)
        case let .cached(value), let .loaded(value):
            guard let requestedAmount = value else {
                requestedView.isHidden = true
                self.loadingState.remove(.amount)
                return
            }

            assetAmountLabel.text = requestedAmount.amount
            fiatAmountLabel.text = requestedAmount.price
            self.loadingState.remove(.amount)
        }
    }

    func setBackgroundGradient(model: GradientModel) {
        gradientView.bind(model: model)
    }
}

// MARK: SkeletonableView

extension VoteCardView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let summaryRows = createSummarySkeletons(for: spaceSize)
        let requestedRows = createRequestedSkeletons(for: spaceSize)

        return summaryRows + requestedRows
    }

    func createRequestedSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        var lastY = spaceSize.height - 150

        let rows = zip(
            Constants.skeletonRequestedLineWidths,
            Constants.skeletonRequestedLineHeights
        )
        .enumerated()
        .map { index, size in
            let size = CGSize(
                width: size.0,
                height: size.1
            )

            let yPoint = lastY + (index > 0 ? Constants.contentSpacing : 0)
            lastY = yPoint + size.height

            let offset = CGPoint(
                x: Constants.contentInset,
                y: yPoint
            )

            return SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: size
            )
        }

        return rows
    }

    func createSummarySkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let baseWidth = bounds.width - Constants.contentInset * 2

        let rows: [Skeletonable] = (0 ... 2).map { index in
            let scale = NSDecimalNumber(
                decimal: pow(Decimal(0.65), index)
            ).doubleValue

            let size = CGSize(
                width: baseWidth * scale,
                height: Constants.skeletonSummaryLineHeight
            )

            let offset = CGPoint(
                x: Constants.contentInset,
                y: Constants.contentInset + (size.height + Constants.contentSpacing) * CGFloat(index)
            )

            return SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: size
            )
        }

        return rows
    }

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [summaryLabel, requestedView]
    }
}

private extension VoteCardView {
    func setupLayout() {
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let content = UIView.vStack(
            spacing: Constants.contentSpacing,
            [
                summaryLabel,
                FlexibleSpaceView(),
                requestedView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(Constants.contentInset)
        }

        addSubview(readMoreButton)
        readMoreButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(Constants.contentInset)
            make.top.equalTo(content.snp.bottom).offset(Constants.buttonTopOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

// MARK: Loading

extension VoteCardView {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let amount = LoadingState(rawValue: 1 << 0)
        static let summary = LoadingState(rawValue: 1 << 1)
        static let all: LoadingState = [.amount, .summary]
        static let none: LoadingState = []

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}

// MARK: Constants

private extension VoteCardView {
    enum Constants {
        static let contentInset: CGFloat = 24
        static let contentSpacing: CGFloat = 12
        static let requestedViewInnerSpacing: CGFloat = 8
        static let buttonTopOffset: CGFloat = 16
        static let skeletonSummaryLineHeight: CGFloat = 12
        static let skeletonRequestedLineHeights: [CGFloat] = [10.0, 16.0, 8.0]
        static let skeletonRequestedLineWidths: [CGFloat] = [69, 118, 53]
    }
}

enum VoteResult {
    case aye
    case nay
    case abstain
    case skip

    var dismissalDirection: CardsZStack.DismissalDirection {
        switch self {
        case .aye:
            .right
        case .nay:
            .left
        case .abstain:
            .top
        case .skip:
            .bottom
        }
    }

    init(from dismissalDirection: CardsZStack.DismissalDirection) {
        switch dismissalDirection {
        case .right:
            self = .aye
        case .left:
            self = .nay
        case .top:
            self = .abstain
        case .bottom:
            self = .skip
        }
    }
}
