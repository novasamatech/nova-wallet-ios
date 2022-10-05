import UIKit
import SoraUI

protocol SkeletonableView: UIView {
    var skeletonView: SkrullableView? { get set }
    var skeletonSuperview: UIView { get }
    var hidingViews: [UIView] { get }
    func startLoadingIfNeeded()
    func stopLoadingIfNeeded()
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable]
    func updateLoadingState()
}

protocol SkeletonableViewCell {
    func updateLoadingState()
}

extension SkeletonableView {
    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        hidingViews.forEach { $0.alpha = 0 }
        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        hidingViews.forEach { $0.alpha = 1 }
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let newSkeletonView = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            newSkeletonView.autoresizingMask = []
            skeletonSuperview.addSubview(newSkeletonView)
            skeletonView = newSkeletonView
            newSkeletonView.startSkrulling()
            currentSkeletonView = newSkeletonView
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }
}

extension BlurredTableViewCell: SkeletonableViewCell where TContentView: SkeletonableView {
    func updateLoadingState() {
        view.updateLoadingState()
    }
}
