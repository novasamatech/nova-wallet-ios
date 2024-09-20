import UIKit
import SnapKit

protocol CardStackable: AnyObject {
    func didBecomeTopView()
    func didAddToStack()
    func didPopFromStack(direction: CardsZStack.DismissalDirection)
    func prepareForReuse()
}

struct CardsZStackViewModel {
    let allCards: [VoteCardId: VoteCardViewModel]
    let changeModel: CardsZStackChangeModel
    let emptyViewModel: SwipeGovEmptyStateViewModel
    let validationAction: ((VoteCardViewModel?) -> Bool)?

    var stackIsEmpty: Bool {
        allCards.isEmpty
    }
}

struct CardsZStackChangeModel {
    let inserts: [VoteCardViewModel]
    let updates: [VoteCardId: VoteCardViewModel]
    let deletes: Set<VoteCardId>
}

final class CardsZStack: UIView {
    enum DismissalDirection {
        case left
        case right
        case top
        case bottom
    }

    private let maxCardsAlive: Int
    private var stackedViews: [VoteCardView] = []
    private var dismissingIds = Set<VoteCardId>()
    private var emptyStateView: UIView?
    private var viewPool: [VoteCardView] = []
    private var viewModelsQueue: [VoteCardViewModel] = []

    private var validateAction: ((VoteCardViewModel?) -> Bool)?

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

    func setupValidationAction(_ closure: ((VoteCardViewModel?) -> Bool)?) {
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
            let id = topView.viewModel?.id
        else {
            return
        }

        if let validateAction, !validateAction(topView.viewModel) {
            createHapticFeedback(style: .heavy)
            animateTransformIdentity(for: topView)

            return
        }

        dismissingIds.insert(id)

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
}

// MARK: - Animate

private extension CardsZStack {
    func animateStackManage() {
        stackedViews.reversed().enumerated().forEach { index, view in
            let (scale, scaleTransform): (CGFloat, CGAffineTransform) = createScaleTransform(
                for: index
            )
            let translationTransform = createTranslationTransform(
                cardIndex: index,
                cardScale: scale,
                insertLast: false
            )
            let finalTransform = scaleTransform.concatenating(translationTransform)

            UIView.animate(
                withDuration: Constants.StackManagingAnimation.duration,
                delay: Constants.StackManagingAnimation.delay,
                usingSpringWithDamping: Constants.StackManagingAnimation.springDamping,
                initialSpringVelocity: Constants.StackManagingAnimation.springVelocity,
                options: [.curveEaseInOut]
            ) {
                view.transform = finalTransform
            }
        }
    }

    func animateCardAdd(_ cardView: UIView) {
        let (scale, scaleTransform): (CGFloat, CGAffineTransform) = createScaleTransform(
            for: stackedViews.endIndex
        )
        let translationTransform = createTranslationTransform(
            cardIndex: stackedViews.endIndex,
            cardScale: scale,
            insertLast: true
        )

        cardView.alpha = 0
        cardView.transform = scaleTransform

        UIView.animate(
            withDuration: Constants.CardAddAnimation.duration,
            delay: Constants.CardAddAnimation.delay,
            usingSpringWithDamping: Constants.CardAddAnimation.springDamping,
            initialSpringVelocity: Constants.CardAddAnimation.springVelocity,
            options: [.curveEaseInOut]
        ) {
            cardView.alpha = 1
            cardView.transform = scaleTransform.concatenating(translationTransform)
        }
    }

    func animateCardDismiss(
        _ topCard: UIView,
        direction: DismissalDirection,
        completion: @escaping () -> Void
    ) {
        let translation: (x: CGFloat, y: CGFloat) = switch direction {
        case .left: (-1.5 * bounds.width, 0)
        case .right: (1.5 * bounds.width, 0)
        case .top: (0, -1.5 * bounds.height)
        case .bottom: (0, 1.5 * bounds.height)
        }

        let rotationDirection: CGFloat = switch direction {
        case .left: -1
        case .right: 1
        case .top: 0
        case .bottom: 0
        }

        UIView.animate(
            withDuration: Constants.CardDismissAnimation.duration,
            animations: {
                topCard.transform = CGAffineTransform(rotationAngle: 0.15 * rotationDirection)
                    .translatedBy(x: translation.x, y: translation.y)
            },
            completion: { _ in
                completion()
            }
        )
    }

    func createScaleTransform(
        for cardIndex: Int
    ) -> (scale: CGFloat, transform: CGAffineTransform) {
        let scale = NSDecimalNumber(
            decimal: pow(Decimal(Constants.stackZScaling), cardIndex)
        ).doubleValue

        let transform = CGAffineTransform(
            scaleX: scale,
            y: scale
        )

        return (scale, transform)
    }

    func createTranslationTransform(
        cardIndex: Int,
        cardScale: CGFloat,
        insertLast: Bool
    ) -> CGAffineTransform {
        guard let baseHeight = stackedViews.last?.frame.height else {
            return .identity
        }

        let prevIndex = cardIndex > 0
            ? cardIndex - 1
            : cardIndex

        let heightDelta = (baseHeight - (baseHeight * cardScale)) / 2
        let translationY = heightDelta + Constants.lowerCardsOffset * CGFloat(insertLast ? prevIndex : cardIndex)

        return CGAffineTransform(
            translationX: .zero,
            y: translationY
        )
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
        emptyStateView?.transform = CGAffineTransform(
            scaleX: Constants.emptyStateHideScaling,
            y: Constants.emptyStateHideScaling
        )
    }

    func showEmptyState() {
        guard let emptyStateView else { return }
        emptyStateView.isHidden = false
        UIView.animate(
            withDuration: Constants.EmptyStateAnimation.startDuration,
            animations: {
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
        case .changed:
            view.transform = CGAffineTransform(
                translationX: translation.x,
                y: translation.y
            )
        case .ended:
            onPanGestureEnded(for: view, with: translation)
        default:
            break
        }
    }

    func onPanGestureEnded(
        for view: VoteCardView,
        with translation: CGPoint
    ) {
        if translation.y <= Constants.topMostY {
            dismissTopCard(to: .top)
        } else if translation.x <= Constants.leftMostX {
            dismissTopCard(to: .left)
        } else if translation.x >= Constants.rightMostX {
            dismissTopCard(to: .right)
        } else {
            animateTransformIdentity(for: view)
        }
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

private extension CardsZStack {
    enum Constants {
        enum CardIdentityAnimation {
            static let duration: CGFloat = 0.35
            static let delay: CGFloat = .zero
            static let springDamping: CGFloat = 0.75
            static let springVelocity: CGFloat = 0.6
        }

        enum CardDismissAnimation {
            static let duration: CGFloat = 0.35
        }

        enum CardAddAnimation {
            static let duration: CGFloat = 0.35
            static let delay: CGFloat = .zero
            static let springDamping: CGFloat = 0.75
            static let springVelocity: CGFloat = 0.6
        }

        enum StackManagingAnimation {
            static let duration: CGFloat = 0.3
            static let delay: CGFloat = .zero
            static let springDamping: CGFloat = 0.6
            static let springVelocity: CGFloat = 0.3
        }

        enum EmptyStateAnimation {
            static let startDuration: CGFloat = 0.2
            static let endDuration: CGFloat = 0.1
        }

        static let emptyStateHideScaling: CGFloat = 0.8
        static let emptyStateShowScaling: CGFloat = 1.05
        static let cardCornerRadius: CGFloat = 16
        static let stackZScaling: CGFloat = 0.9
        static let lowerCardsOffset: CGFloat = 10.0
        static let horizontalScreenSizeDivider: CGFloat = 3.15
        static let verticalScreenSizeDivider: CGFloat = 3.8
        static let topMostY = -(UIScreen.main.bounds.height / Constants.verticalScreenSizeDivider)
        static let leftMostX = -(UIScreen.main.bounds.width / Constants.horizontalScreenSizeDivider)
        static let rightMostX = UIScreen.main.bounds.width / Constants.horizontalScreenSizeDivider
    }
}
