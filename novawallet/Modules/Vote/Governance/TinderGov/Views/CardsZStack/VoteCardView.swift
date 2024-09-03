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

    private var viewModel: VoteCardViewModel?

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
}

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

extension VoteCardView: StackCardViewUpdatable {
    func setSummary(loadingState: LoadableViewModelState<String>) {
        switch loadingState {
        case .loading:
            // TODO: Implement
            break
        case let .cached(value), let .loaded(value):
            summaryLabel.text = value
        }
    }

    func setRequestedAmount(loadingState: LoadableViewModelState<VoteCardViewModel.RequestedAmount?>) {
        switch loadingState {
        case .loading:
            // TODO: Implement
            break
        case let .cached(value), let .loaded(value):
            guard let requestedAmount = value else {
                requestedView.isHidden = true
                return
            }

            assetAmountLabel.text = requestedAmount.assetAmount
            fiatAmountLabel.text = requestedAmount.fiatAmount
        }
    }

    func setBackgroundGradient(model: GradientModel) {
        gradientView.bind(model: model)
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

// MARK: Constants

private extension VoteCardView {
    enum Constants {
        static let contentInset: CGFloat = 24
        static let contentSpacing: CGFloat = 12
        static let requestedViewInnerSpacing: CGFloat = 8
        static let buttonTopOffset: CGFloat = 16
    }
}

enum VoteResult {
    case aye
    case nay
    case abstain

    var dismissalDirection: CardsZStack.DismissalDirection {
        switch self {
        case .aye:
            .right
        case .nay:
            .left
        case .abstain:
            .top
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
        }
    }
}
