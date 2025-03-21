import UIKit
import SnapKit

final class CardsZStack: UIView {
    private let maxCardsAlive: Int
    private(set) var stackedViews: [VoteCardView] = []
    private(set) var dismissingIds = Set<VoteCardId>()
    private(set) var emptyStateView: UIView?
    private(set) var viewPool: [VoteCardView] = []
    private(set) var viewModelsQueue: [VoteCardViewModel] = []

    private var validateAction: VoteCardValidationClosure?
    private var panState = VoteCardPanState()

    init(maxCardsAlive: Int = 3) {
        self.maxCardsAlive = maxCardsAlive
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Should be called after adding batch of cards, to inform top card that it's presented and became top
    /// `cardsStack.notifyTopView` is called automatically on top card in stack after dismissal animation
    func notifyTopView() {
        guard let topView = stackedViews.last else {
            showEmptyState()
            return
        }
        topView.didBecomeTopView()
    }

    func setupValidationAction(_ closure: VoteCardValidationClosure?) {
        validateAction = closure
    }

    func addCard(model: VoteCardViewModel) {
        viewModelsQueue.append(model)
        manageStack()
    }

    func setEmptyStateView(_ view: UIView) {
        emptyStateView = view
        view.isHidden = true
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        sendSubviewToBack(view)
    }

    func dismissTopCard(
        to direction: DismissalDirection,
        completion: (() -> Void)? = nil
    ) {
        guard
            let topView = currentTopView(startionFrom: stackedViews.endIndex - 1),
            let viewModel = topView.viewModel
        else {
            return
        }

        if let validateAction, !validateAction(viewModel, VoteResult(from: direction)) {
            createHapticFeedback(style: .heavy)
            resetPanCardState(for: topView)

            return
        }

        topView.didPredict(vote: .init(from: direction))

        dismissingIds.insert(viewModel.id)

        createHapticFeedback(style: .medium)
        animateCardDismiss(topView, direction: direction) { [weak self] in
            self?.processCardDidPop(
                cardView: topView,
                direction: direction,
                completion: completion
            )
        }
    }

    func currentTopView(startionFrom index: Int) -> VoteCardView? {
        guard index < stackedViews.count, index >= 0 else {
            return nil
        }

        let view = stackedViews[index]

        if let id = view.viewModel?.id, dismissingIds.contains(id) {
            return currentTopView(startionFrom: index - 1)
        } else {
            return view
        }
    }

    func skipCard() {
        guard let topView = stackedViews.last else {
            return
        }

        animateCardDismiss(topView, direction: .bottom) { [weak self] in
            self?.processCardDidPop(
                cardView: topView,
                direction: .bottom
            )
        }
    }

    func removeCard(with id: UInt) {
        if let index = viewModelsQueue.firstIndex(where: { $0.id == id }) {
            viewModelsQueue.remove(at: index)
        }

        guard let cardView = stackedViews.first(where: { $0.viewModel?.id == id }) else {
            return
        }

        let dismissDirection: DismissalDirection = .bottom
        animateCardDismiss(cardView, direction: dismissDirection) { [weak self] in
            self?.processCardDidPop(
                cardView: cardView,
                direction: dismissDirection,
                completion: nil
            )
        }
    }

    func updateStack(with changeModel: CardsZStackChangeModel) {
        if !changeModel.deletes.isEmpty || !changeModel.updates.isEmpty {
            viewModelsQueue
                .enumerated()
                .reversed()
                .forEach { index, viewModel in
                    if changeModel.deletes.contains(viewModel.id) {
                        viewModelsQueue.remove(at: index)
                    } else if let updatedModel = changeModel.updates[viewModel.id] {
                        viewModelsQueue[index] = updatedModel
                    }
                }
        }

        changeModel.inserts.forEach { viewModel in
            viewModelsQueue.append(viewModel)
        }

        manageStack()
    }

    func dismissTopIf(cardId: VoteCardId, voteResult: VoteResult) {
        guard
            let topView = currentTopView(startionFrom: stackedViews.endIndex - 1),
            topView.viewModel?.id == cardId
        else {
            return
        }

        dismissTopCard(to: voteResult.dismissalDirection)
    }
}

// MARK: Private

private extension CardsZStack {
    func addView(_ view: VoteCardView) {
        stackedViews.insert(view, at: 0)

        if let emptyStateView {
            insertSubview(view, aboveSubview: emptyStateView)
        } else {
            insertSubview(view, at: 0)
        }

        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        layoutIfNeeded()

        if stackedViews.count == 1 {
            hideEmptyState()
        }

        animateCardAdd(view)
    }

    func processCardDidPop(
        cardView: VoteCardView,
        direction: DismissalDirection,
        completion: (() -> Void)? = nil
    ) {
        guard let id = cardView.viewModel?.id else {
            return
        }

        cardView.didPopFromStack(direction: direction)

        stackedViews.removeAll(where: { $0.viewModel?.id == cardView.viewModel?.id })
        dismissingIds.remove(id)

        enqueueVoteCardView(cardView)
        notifyTopView()

        if stackedViews.isEmpty {
            showEmptyState()
        }

        manageStack()
        completion?()
    }

    func dequeueVoteCardView() -> VoteCardView {
        viewPool.popLast() ?? createCardView()
    }

    func createCardView() -> VoteCardView {
        let view = VoteCardView()
        view.cornerRadius = Constants.cardCornerRadius
        view.strokeColor = .clear

        view.layer.borderWidth = 1
        view.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        view.layer.cornerRadius = Constants.cardCornerRadius
        view.shadowColor = UIColor.black
        view.shadowOpacity = 0.35
        view.shadowOffset = CGSize(width: 0, height: 4)

        addPanGestureRecognizer(for: view)

        return view
    }

    func enqueueVoteCardView(_ view: VoteCardView) {
        view.snp.removeConstraints()
        viewPool.append(view)
        view.removeFromSuperview()
    }

    func manageStack() {
        while stackedViews.count < maxCardsAlive, !viewModelsQueue.isEmpty {
            let cardModel = viewModelsQueue.removeFirst()
            let voteCard = dequeueVoteCardView()
            voteCard.prepareForReuse()
            voteCard.bind(with: cardModel)
            voteCard.didAddToStack()

            addView(voteCard)
        }

        animateStackManage()
    }

    func hideEmptyState() {
        guard let emptyStateView else { return }

        let hiddenTransform = CGAffineTransform(
            scaleX: Constants.emptyStateHideScaling,
            y: Constants.emptyStateHideScaling
        )

        let duration = Constants.EmptyStateAnimation.startDuration + Constants.EmptyStateAnimation.endDuration

        UIView.animate(
            withDuration: duration,
            animations: {
                emptyStateView.transform = hiddenTransform
                emptyStateView.alpha = 0
            },
            completion: { _ in emptyStateView.isHidden = true }
        )
    }

    func showEmptyState() {
        guard let emptyStateView, emptyStateView.isHidden else { return }

        emptyStateView.alpha = 0
        emptyStateView.isHidden = false
        UIView.animate(
            withDuration: Constants.EmptyStateAnimation.startDuration,
            animations: {
                emptyStateView.alpha = 1
                emptyStateView.transform = CGAffineTransform(
                    scaleX: Constants.emptyStateShowScaling,
                    y: Constants.emptyStateShowScaling
                )
            },
            completion: { _ in
                UIView.animate(withDuration: Constants.EmptyStateAnimation.endDuration) {
                    emptyStateView.transform = .identity
                }
            }
        )
    }

    func addPanGestureRecognizer(for view: UIView) {
        view.addGestureRecognizer(
            UIPanGestureRecognizer(
                target: self,
                action: #selector(actionPan(gestureRecognizer:))
            )
        )
    }

    @objc func actionPan(gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = (gestureRecognizer.view as? VoteCardView) else {
            return
        }

        let translation = gestureRecognizer.translation(in: view)

        switch gestureRecognizer.state {
        case .began:
            panState.onPanBegin(point: translation)
        case .changed:
            panState.onPanChange(point: translation)

            view.transform = CGAffineTransform(
                translationX: translation.x,
                y: translation.y
            )

            if let direction = panState.predictDirection() {
                view.didPredict(vote: .init(from: direction))
            } else {
                view.didResetVote()
            }
        case .ended:
            panState.onPanChange(point: translation)

            if let direction = panState.predictDirection() {
                dismissTopCard(to: direction)
            } else {
                resetPanCardState(for: view)
            }
        case .failed, .cancelled, .possible:
            resetPanCardState(for: view)
        default:
            break
        }
    }

    func resetPanCardState(for view: VoteCardView) {
        view.didResetVote()

        animateTransformIdentity(for: view)
    }

    func animateTransformIdentity(for view: UIView) {
        UIView.animate(
            withDuration: Constants.CardIdentityAnimation.duration,
            delay: Constants.CardIdentityAnimation.delay,
            usingSpringWithDamping: Constants.CardIdentityAnimation.springDamping,
            initialSpringVelocity: Constants.CardIdentityAnimation.springVelocity,
            options: [.curveEaseInOut]
        ) {
            view.transform = .identity
        }
    }

    func createHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

extension CardsZStack {
    enum DismissalDirection {
        case left
        case right
        case top
        case bottom
    }

    struct Actions {
        let emptyViewAction: () -> Void
        let validationClosure: VoteCardValidationClosure
    }
}
