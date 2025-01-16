import UIKit
import UIKit_iOS

struct SkeletonableViewReplica {
    let count: UInt32
    let spacing: CGFloat
}

protocol SkeletonableView: UIView {
    var skeletonSpaceSize: CGSize { get }
    var skeletonReplica: SkeletonableViewReplica { get }
    var skeletonView: SkrullableView? { get set }
    var skeletonSuperview: UIView { get }
    var hidingViews: [UIView] { get }
    func startLoadingIfNeeded()
    func stopLoadingIfNeeded()
    func didStartSkeleton()
    func didStopSkeleton()
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable]
    func createDecorations(for spaceSize: CGSize) -> [Decorable]
    func updateLoadingState()
}

protocol SkeletonableViewCell {
    func updateLoadingState()
}

extension SkeletonableView {
    func startLoadingIfNeeded() {
        hidingViews.forEach { $0.alpha = 0 }

        didStartSkeleton()

        guard skeletonView == nil else {
            return
        }

        setupSkeleton()

        if skeletonView != nil {
            hidingViews.forEach { $0.alpha = 0 }
        }
    }

    func stopLoadingIfNeeded() {
        hidingViews.forEach { $0.alpha = 1 }

        didStopSkeleton()

        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
    }

    var skeletonSpaceSize: CGSize { frame.size }

    var skeletonReplica: SkeletonableViewReplica { SkeletonableViewReplica(count: 1, spacing: 0) }

    func updateLoadingState() {
        setupSkeleton()
    }

    private func setupSkeleton() {
        let spaceSize = skeletonSpaceSize

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        var builder = Skrull(
            size: spaceSize,
            decorations: createDecorations(for: spaceSize),
            skeletons: createSkeletons(for: spaceSize)
        )

        let replica = skeletonReplica
        if replica.count > 1 {
            builder = builder.replicateVertically(count: replica.count, spacing: replica.spacing)
        }

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

    func createDecorations(for _: CGSize) -> [Decorable] { [] }

    func didStartSkeleton() {}
    func didStopSkeleton() {}
}

extension BlurredTableViewCell: SkeletonableViewCell where TContentView: SkeletonableView {
    func updateLoadingState() {
        view.updateLoadingState()
    }
}
