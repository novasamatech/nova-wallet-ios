import UIKit

protocol GridUnitTransitionCoordinatorSourceProtocol {
    func applyTransition(for view: UIView)
    func finishTransition()
}

protocol GridUnitTransitionCoordinatorProtocol: GridUnitTransitionCoordinatorSourceProtocol {
    func setupInsertion(viewHolder: UIView, parentView: UIView)
}

final class GridUnitTransitionCoordinator {
    private var destinationViewHolder: UIView?
    private var destinationParentView: UIView?

    private var currentView: UIView?
}

extension GridUnitTransitionCoordinator: GridUnitTransitionCoordinatorProtocol {
    func setupInsertion(viewHolder: UIView, parentView: UIView) {
        destinationViewHolder = viewHolder
        destinationParentView = parentView
    }

    func applyTransition(for view: UIView) {
        guard
            let destinationViewHolder,
            let destinationParentView,
            let window = UIApplication.shared.windows.first
        else { return }

        currentView = view

        let destinationPoint = destinationParentView.convert(
            destinationViewHolder.center,
            to: window
        )

        view.removeFromSuperview()
        window.addSubview(view)

        view.center = destinationPoint
    }

    func finishTransition() {
        guard let currentView else { return }

        currentView.removeFromSuperview()
        destinationViewHolder?.addSubview(currentView)
    }
}
