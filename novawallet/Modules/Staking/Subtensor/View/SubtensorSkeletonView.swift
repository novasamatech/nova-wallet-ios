import UIKit
import UIKit_iOS

final class SubtensorSkeletonView: UIView, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { self }
    var hidingViews: [UIView] { [] }
    var skeletonCornerRadius: CGFloat?

    private var loading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        clipsToBounds = true
        isHidden = true
    }

    convenience init(cornerRadius: CGFloat) {
        self.init(frame: .zero)
        layer.cornerRadius = cornerRadius
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if loading { updateLoadingState() }
    }

    func setLoading(_ value: Bool) {
        loading = value
        isHidden = !value
        if value { startLoadingIfNeeded() } else { stopLoadingIfNeeded() }
    }

    func createSkeletons(for size: CGSize) -> [Skeletonable] {
        let cornerRadii = skeletonCornerRadius.map { CGSize(width: $0 / size.width, height: $0 / size.height) }

        return [SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: size,
            offset: .zero,
            size: size,
            cornerRadii: cornerRadii ?? CGSize(width: 0.5, height: 0.5)
        )]
    }
}
