import SnapKit
import UIKit
import UIKit_iOS
import CDMarkdownKit

final class VoteCardView: RoundedView {
    private let gradientView: RoundedGradientBackgroundView = .create { view in
        view.applyCellBackgroundStyle()
    }

    private var summaryLabel: UILabel = .create { view in
        view.numberOfLines = 0
        view.textAlignment = .left
    }

    var skeletonView: SkrullableView?

    let dividerView: BorderedContainerView = .create { view in
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDivider()!
        view.borderType = .top
    }

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

    private var voteOverlayView: VoteCardOverlayView?
    private var voteInAnimator = FadeAnimator(from: 0, to: 1, duration: 0.2, delay: 0, options: .curveLinear)
    private var voteOutAnimator = FadeAnimator(from: 1, to: 0, duration: 0.2, delay: 0, options: .curveLinear)

    let summaryContentView = UIView()

    private lazy var readMoreButton: LoadableActionView = .create { view in
        view.actionButton.applyEnabledStyle(colored: R.color.colorButtonBackgroundSecondary()!)
        view.actionButton.imageWithTitleView?.title = R.string.localizable.commonReadMore(
            preferredLanguages: viewModel?.locale.rLanguages
        )
    }

    private(set) var viewModel: VoteCardViewModel?
    private var isOnStack = false

    private var loadingState: LoadingState = .none {
        didSet {
            if loadingState == .none {
                stopLoadingIfNeeded()
            } else {
                startLoadingIfNeeded()
            }
        }
    }

    var summaryMaxSize: CGSize {
        CGSize(
            width: summaryContentView.frame.width,
            height: summaryContentView.frame.height * Constants.summaryHeightMultiplier
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if loadingState != .none {
            updateLoadingState()
        }

        if isOnStack {
            viewModel?.onResize(for: summaryMaxSize)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        setupAction()

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

        isOnStack = true
        viewModel?.onResize(for: summaryMaxSize)
    }

    func didPopFromStack(direction: CardsZStack.DismissalDirection) {
        viewModel?.onPop(direction: direction)
        isOnStack = false
    }

    func didPredict(vote: VoteResult) {
        guard vote != voteOverlayView?.vote else {
            return
        }

        let optVoteView = voteOverlayView
        let newVoteView = setupOverlay(for: vote)

        animateOverlayIn(view: newVoteView)

        if let oldVoteView = optVoteView {
            animateOverlayOut(view: oldVoteView)
        }
    }

    func didResetVote() {
        guard let voteOverlayView else {
            return
        }

        self.voteOverlayView = nil

        animateOverlayOut(view: voteOverlayView)
    }

    func prepareForReuse() {
        transform = .identity
        summaryLabel.text = nil
        assetAmountLabel.text = nil
        fiatAmountLabel.text = nil
        requestedView.isHidden = false
        dividerView.isHidden = false
        viewModel = nil
        isOnStack = false

        voteOverlayView?.removeFromSuperview()
        voteOverlayView = nil
    }
}

// MARK: StackCardViewUpdatable

extension VoteCardView: StackCardViewUpdatable {
    func setSummary(loadingState: LoadableViewModelState<NSAttributedString>) {
        switch loadingState {
        case .loading:
            break
        case let .cached(value), let .loaded(value):
            summaryLabel.attributedText = value
        }
    }

    func setRequestedAmount(loadingState: LoadableViewModelState<BalanceViewModelProtocol?>) {
        switch loadingState {
        case .loading:
            self.loadingState.formUnion(.amount)
        case let .cached(value), let .loaded(value):
            if let requestedAmount = value {
                assetAmountLabel.text = requestedAmount.amount
                fiatAmountLabel.text = requestedAmount.price
                self.loadingState.remove(.amount)
            } else {
                requestedView.isHidden = true
                dividerView.isHidden = true
                self.loadingState.remove(.amount)
            }

            layoutIfNeeded()
            viewModel?.onResize(for: summaryMaxSize)
        }
    }

    func setBackgroundGradient(model: GradientModel) {
        gradientView.bind(model: model)
    }
}

// MARK: SkeletonableView

extension VoteCardView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let requestedRows = createRequestedSkeletons(for: spaceSize)

        return requestedRows
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

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [requestedView]
    }
}

private extension VoteCardView {
    func setupLayout() {
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        summaryContentView.addSubview(summaryLabel)
        summaryLabel.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.lessThanOrEqualToSuperview().multipliedBy(Constants.summaryHeightMultiplier)
        }

        let content = UIView.vStack(
            spacing: Constants.contentSpacing,
            [
                summaryContentView,
                requestedView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(Constants.contentInset)
        }

        addSubview(dividerView)
        dividerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(requestedView)
            make.top.equalTo(requestedView.snp.top).offset(-Constants.contentSpacing)
        }

        addSubview(readMoreButton)
        readMoreButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(Constants.contentInset)
            make.top.equalTo(content.snp.bottom).offset(Constants.buttonTopOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func setupOverlay(for vote: VoteResult) -> VoteCardOverlayView {
        let voteView = VoteCardOverlayView()
        addSubview(voteView)

        voteOverlayView = voteView

        switch vote {
        case .aye:
            voteView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().inset(Constants.voteOverlayHorizontalInset)
                make.bottom.equalTo(dividerView.snp.top).offset(-Constants.voteOverlayBottomInset)
            }
        case .nay:
            voteView.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(Constants.voteOverlayHorizontalInset)
                make.bottom.equalTo(dividerView.snp.top).offset(-Constants.voteOverlayBottomInset)
            }
        case .abstain, .skip:
            voteView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalTo(dividerView.snp.top).offset(-Constants.voteOverlayBottomInset)
            }
        }

        voteOverlayView?.bind(vote: vote)

        return voteView
    }

    private func animateOverlayIn(view: VoteCardOverlayView) {
        voteInAnimator.animate(view: view, completionBlock: nil)
    }

    private func animateOverlayOut(view: VoteCardOverlayView) {
        voteOutAnimator.animate(view: view) { [weak view] _ in
            view?.removeFromSuperview()
        }
    }
}

// MARK: Loading

extension VoteCardView {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let amount = LoadingState(rawValue: 1 << 0)
        static let all: LoadingState = [.amount]
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
        static let voteOverlayHorizontalInset = 16
        static let voteOverlayBottomInset = 30
        static let summaryHeightMultiplier = 0.8
    }
}

enum VoteResult: Equatable {
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
