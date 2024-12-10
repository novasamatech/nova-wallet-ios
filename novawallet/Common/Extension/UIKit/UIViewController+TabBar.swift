import UIKit

extension UIViewController {
    func setTabBarHidden(
        _ hidden: Bool,
        animated: Bool = true,
        duration: TimeInterval = 0.25
    ) {
        guard
            let tabBar = tabBarController?.tabBar,
            tabBar.isHidden != hidden,
            let rootContainer = tabBarController?.parent as? NovaMainAppContainerViewController,
            let window = view.window
        else {
            return
        }

        if tabBar.isHidden {
            tabBar.isHidden = hidden
        }

        let yPoint = calculateYPoint(
            for: tabBar.frame,
            inside: rootContainer,
            hiding: hidden,
            window: window
        )

        let layoutClosure: () -> Void = {
            tabBar.frame = CGRect(
                x: tabBar.frame.origin.x,
                y: yPoint,
                width: tabBar.frame.width,
                height: tabBar.frame.height
            )
        }

        if animated {
            UIView.animate(
                withDuration: duration,
                animations: { layoutClosure() }
            ) { _ in
                guard !tabBar.isHidden else { return }

                tabBar.isHidden = hidden
            }
        } else {
            layoutClosure()
        }
    }

    private func calculateYPoint(
        for frame: CGRect,
        inside rootContainer: NovaMainAppContainerViewController,
        hiding: Bool,
        window: UIWindow
    ) -> CGFloat {
        let topContainerBottomOffset = rootContainer.topContainerBottomOffset
        let factor: CGFloat = hiding ? 1 : -1

        let distance: CGFloat = frame.size.height + topContainerBottomOffset

        let point: CGFloat = window.frame.height + distance * factor

        return point
    }
}
