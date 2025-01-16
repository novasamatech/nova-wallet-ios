import UIKit
import UIKit_iOS
import SnapKit

protocol GridUnitTransitionCoordinatorSourceProtocol {
    func setupProposition(
        view: UIControl,
        onFinish: @escaping () -> Void
    )

    func startTransition(with animator: BlockViewAnimatorProtocol?)
}

protocol GridUnitTransitionCoordinatorProtocol: GridUnitTransitionCoordinatorSourceProtocol {
    func setupInsertion(
        viewHolder: UIView,
        parentView: UIView,
        onFinish: @escaping (UIControl) -> Void
    )
}

final class GridUnitTransitionCoordinator {
    private var destinationViewHolder: UIView?
    private var destinationParentView: UIView?

    private var destinationOnFinish: ((UIControl) -> Void)?
    private var sourceOnFinish: (() -> Void)?

    private var viewToInsert: UIControl?
}

extension GridUnitTransitionCoordinator: GridUnitTransitionCoordinatorProtocol {
    func setupProposition(
        view: UIControl,
        onFinish: @escaping () -> Void
    ) {
        viewToInsert = view
        sourceOnFinish = onFinish
    }

    func setupInsertion(
        viewHolder: UIView,
        parentView: UIView,
        onFinish: @escaping (UIControl) -> Void
    ) {
        destinationViewHolder = viewHolder
        destinationParentView = parentView

        destinationOnFinish = onFinish
    }

    func startTransition(with animator: BlockViewAnimatorProtocol?) {
        guard
            let viewToInsert,
            let sourceViewHolder = viewToInsert.superview,
            let destinationViewHolder,
            let destinationParentView
        else {
            return
        }

        viewToInsert.removeFromSuperview()
        destinationViewHolder.addSubview(viewToInsert)

        var sourceConstraints: Constraint?
        var destinationConstraint: Constraint?

        viewToInsert.snp.makeConstraints { make in
            destinationConstraint = make.edges.equalTo(destinationViewHolder).constraint
            destinationConstraint?.deactivate()

            sourceConstraints = make.edges.equalTo(sourceViewHolder).constraint
        }

        destinationParentView.layoutIfNeeded()

        viewToInsert.removeTarget(nil, action: nil, for: .allEvents)

        sourceOnFinish?()
        destinationOnFinish?(viewToInsert)

        sourceConstraints?.deactivate()
        destinationConstraint?.activate()

        animator?.animate(
            block: { destinationParentView.layoutIfNeeded() },
            completionBlock: nil
        )
    }
}
