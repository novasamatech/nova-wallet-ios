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
    }

    private let maxCardsAlive: Int
    private var stackedViews: [VoteCardView] = []
    private var emptyStateView: UIView?
    private var viewPool: [VoteCardView] = []
    private var viewModelsQueue: [VoteCardModel] = []

    init(maxCardsAlive: Int = 5) {
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

    func addView(_ view: VoteCardView, atBottom: Bool = true) {
        if atBottom {
            stackedViews.insert(view, at: 0)
        } else {
            stackedViews.append(view)
        }
        if atBottom, let emptyView = emptyStateView {
            insertSubview(view, aboveSubview: emptyView)
        } else {
            addSubview(view)
            bringSubviewToFront(view)
        }
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if stackedViews.count == 1 {
            hideEmptyState()
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

    func dismissTopCard(to direction: DismissalDirection, completion: (() -> Void)? = nil) {
        guard let topView = stackedViews.last else {
            return
        }

        let translationX = direction == .left ? -1.5 * bounds.width : 1.5 * bounds.width
        let rotationDirection = CGFloat(direction == .left ? -1 : 1)
        UIView.animate(withDuration: 0.35, animations: {
            topView.transform = CGAffineTransform(rotationAngle: 0.15 * rotationDirection)
                .translatedBy(x: translationX, y: 0)
        }, completion: { _ in
            self.stackedViews.removeLast()
            topView.removeFromSuperview()
            self.enqueueVoteCardView(topView)
            self.notifyTopView()
            if self.stackedViews.isEmpty {
                self.showEmptyState()
            }
            self.manageStack()
            completion?()
        })
    }
}

private extension CardsZStack {
    func dequeueVoteCardView() -> VoteCardView {
        viewPool.popLast() ?? VoteCardView()
    }

    func enqueueVoteCardView(_ view: VoteCardView) {
        viewPool.append(view)
        view.removeFromSuperview()
        view.transform = .identity
    }

    func manageStack() {
        while stackedViews.count < maxCardsAlive, !viewModelsQueue.isEmpty {
            let cardModel = viewModelsQueue.removeFirst()
            let voteCard = dequeueVoteCardView()
            voteCard.prepareForReuse()
            voteCard.bind(viewModel: cardModel.viewModel)
            voteCard.bind(action: { [weak self] voteResult in
                self?.dismissTopCard(to: voteResult.dismissalDirection) {
                    cardModel.voteAction(voteResult, cardModel.viewModel.caseIndex)
                }
            })
            voteCard.bind(reportAction: { [weak self] in
                self?.dismissTopCard(to: .left) {
                    cardModel.reportAction(cardModel.viewModel.caseIndex)
                }
            })
            voteCard.bind(skipAction: { [weak self] in
                self?.dismissTopCard(to: .left) {
                    cardModel.skipAction(cardModel.viewModel.caseIndex)
                }
            })
            addView(voteCard, atBottom: true)
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
