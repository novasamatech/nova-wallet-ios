import UIKit
import SnapKit

protocol CardStackable: AnyObject {
    func didBecomeTopView()
    func prepareForReuse()
}

final class CardsZStack: UIView {
    enum DismissalDirection {
        case left
        case right
        case top
    }

    private let stackScale: CGFloat = 0.9
    private let maxCardsAlive: Int
    private var stackedViews: [VoteCardView] = []
    private var emptyStateView: UIView?
    private var viewPool: [VoteCardView] = []
    private var viewModelsQueue: [VoteCardModel] = []

    init(maxCardsAlive: Int = 3) {
        self.maxCardsAlive = maxCardsAlive
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Should be called after adding batch of cards, to inform top card that it's presented and became top
    /// `cardsStack.notifyTopView` is called automatically on top card in stack after dismissal animation, .i.e.
    /// to initialise video playback
    func notifyTopView() {
        guard let topView = stackedViews.last else {
            showEmptyState()
            return
        }
        topView.didBecomeTopView()
    }

    func addCard(model: VoteCardModel) {
        viewModelsQueue.append(model)
        manageStack()
    }

    func addView(_ view: VoteCardView) {
        view.alpha = 0

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

        guard stackedViews.count > 1 else {
            view.alpha = 1

            return
        }

        let prevIndex = stackedViews.endIndex - 1

        let scale = NSDecimalNumber(
            decimal: pow(Decimal(stackScale), prevIndex)
        ).doubleValue

        let gap: CGFloat = 8

        let baseHeight = stackedViews[prevIndex].bounds.height
        let heightDelta = (baseHeight - (baseHeight * scale)) / 2
        let translationY = heightDelta + (gap * CGFloat(prevIndex))

        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let translationTransform = CGAffineTransform(translationX: 0, y: translationY)

        view.transform = scaleTransform

        UIView.animate(withDuration: 0.35) {
            view.alpha = 1
            view.transform = scaleTransform.concatenating(translationTransform)
        }
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
        guard let topView = stackedViews.last else {
            return
        }

        let translation: (x: CGFloat, y: CGFloat) = switch direction {
        case .left: (-1.5 * bounds.width, 0)
        case .right: (1.5 * bounds.width, 0)
        case .top: (0, -1.5 * bounds.height)
        }

        let rotationDirection: CGFloat = switch direction {
        case .left: -1
        case .right: 1
        case .top: 0
        }

        UIView.animate(
            withDuration: 0.35,
            animations: {
                topView.transform = CGAffineTransform(rotationAngle: 0.15 * rotationDirection)
                    .translatedBy(x: translation.x, y: translation.y)
            }
        ) { _ in
            topView.transform = .identity
            self.stackedViews.removeLast()
            topView.removeFromSuperview()
            self.enqueueVoteCardView(topView)
            self.notifyTopView()
            if self.stackedViews.isEmpty {
                self.showEmptyState()
            }
            self.manageStack()
            completion?()
        }
    }
}

private extension CardsZStack {
    func dequeueVoteCardView() -> VoteCardView {
        viewPool.popLast() ?? createCardView()
    }

    func createCardView() -> VoteCardView {
        let view = VoteCardView()
        view.strokeWidth = 2
        view.strokeColor = R.color.colorContainerBorder()!
        view.shadowColor = UIColor.black
        view.shadowOpacity = 0.16
        view.shadowOffset = CGSize(width: 6, height: 4)

        return view
    }

    func enqueueVoteCardView(_ view: VoteCardView) {
        viewPool.append(view)
        view.removeFromSuperview()
    }

    func manageStack() {
        while stackedViews.count < maxCardsAlive, !viewModelsQueue.isEmpty {
            let cardModel = viewModelsQueue.removeFirst()
            let voteCard = dequeueVoteCardView()
            voteCard.cornerRadius = 16
            voteCard.prepareForReuse()
            voteCard.bind(viewModel: cardModel.viewModel)

            addView(voteCard)
        }

        stackedViews.reversed().enumerated().forEach { index, view in
            let scale = NSDecimalNumber(decimal: pow(Decimal(self.stackScale), index)).doubleValue

            let prevIndex = index > 0
                ? index - 1
                : index

            let gap: CGFloat = 8

            let baseHeight = stackedViews[prevIndex].bounds.height
            let heightDelta = (baseHeight - (baseHeight * scale)) / 2
            let translationY = heightDelta + (gap * CGFloat(index))

            let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
            let translationTransform = CGAffineTransform(translationX: 0, y: translationY)
            let concatTransform = scaleTransform.concatenating(translationTransform)

            UIView.animate(withDuration: 0.25) {
                view.transform = concatTransform
            }
        }
    }

    func hideEmptyState() {
        emptyStateView?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }

    func showEmptyState() {
        guard let emptyStateView else { return }
        emptyStateView.isHidden = false
        UIView.animate(withDuration: 0.2, animations: {
            emptyStateView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                emptyStateView.transform = .identity
            }
        })
    }
}
