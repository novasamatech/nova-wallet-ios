import UIKit
import SnapKit
import UIKit_iOS

final class SwipeGovViewLayout: UIView {
    let gradientBackgroundView: MultigradientView = .create { view in
        let gradient = GradientModel.swipeGovBackgroundGradient

        view.colors = gradient.colors
        view.locations = gradient.locations
        view.startPoint = gradient.startPoint
        view.endPoint = gradient.endPoint
    }

    let votingListWidget: VotingListWidget = .create { view in
        view.alpha = 0
    }

    let cardsStack = CardsZStack()

    let ayeButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundApprove()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundApprove()!
        button.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconThumbsUpFilled()
        button.alpha = 0
        return button
    }()

    let abstainButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.cornerRadius = Constants.smallButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconAbstain()
        button.alpha = 0
        return button
    }()

    let nayButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundReject()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundReject()!
        button.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconThumbsDownFilled()
        button.alpha = 0
        return button
    }()

    let emptyStateView = SwipeGovEmptyStateView()

    let controlHideAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.3,
        delay: 0.0,
        options: .curveEaseInOut
    )

    let controlShowAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: 0.3,
        delay: 0.0,
        options: .curveEaseInOut
    )

    var controlsAreHidden: Bool = true
    var votingWidgetIsHidden: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func hideVoteButtons() {
        guard !controlsAreHidden else {
            return
        }

        [nayButton, abstainButton, ayeButton].forEach {
            controlHideAnimator.animate(
                view: $0,
                completionBlock: { [weak self] _ in
                    self?.controlsAreHidden = true
                }
            )
        }
    }

    func showVoteButtons() {
        guard controlsAreHidden else {
            return
        }

        [nayButton, abstainButton, ayeButton].forEach {
            controlShowAnimator.animate(
                view: $0,
                completionBlock: { [weak self] _ in
                    self?.controlsAreHidden = false
                }
            )
        }
    }

    func showVotingListWidget() {
        guard votingWidgetIsHidden else {
            return
        }

        controlShowAnimator.animate(
            view: votingListWidget,
            completionBlock: { [weak self] _ in
                self?.votingWidgetIsHidden = false
            }
        )
    }
}

// MARK: Setup

private extension SwipeGovViewLayout {
    func setupLayout() {
        addSubview(gradientBackgroundView)
        gradientBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(votingListWidget)
        votingListWidget.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(Constants.votingListWidgetTopInset)
            make.centerX.equalToSuperview()
        }

        addSubview(abstainButton)
        abstainButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.smallButtonSize)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        addSubview(nayButton)
        nayButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(abstainButton.snp.leading).offset(Constants.nayButtonTrailingOffset)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        addSubview(ayeButton)
        ayeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.equalTo(abstainButton.snp.trailing).offset(Constants.ayeButtonLeadingOffset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        nayButton.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        ayeButton.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2

        addSubview(cardsStack)
        cardsStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(votingListWidget.snp.bottom).inset(Constants.cardsStackTopInset)
            make.bottom.equalTo(nayButton.snp.top).inset(Constants.cardsStackBottomInset)
        }

        cardsStack.setEmptyStateView(emptyStateView)
    }
}

// MARK: Cards

extension SwipeGovViewLayout {
    /// Should be called after adding batch of cards, to inform top card that it's presented and became top
    /// `cardsStack.notifyTopView` is called automatically on top card in stack after dismissal animation
    func finishedAddingCards() {
        cardsStack.notifyTopView()
    }
}

extension SwipeGovViewLayout {
    enum Constants {
        static let cardsStackBottomInset: CGFloat = -54
        static let cardsStackTopInset: CGFloat = -20
        static let ayeButtonLeadingOffset: CGFloat = 40
        static let nayButtonTrailingOffset: CGFloat = -40
        static let votingListWidgetTopInset: CGFloat = 16
        static let bigButtonSize: CGFloat = 64
        static let smallButtonSize: CGFloat = 56
        static let buttonsBottomInset: CGFloat = 20
    }
}
