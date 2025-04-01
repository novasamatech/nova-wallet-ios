import UIKit
import SnapKit
import UIKit_iOS

final class DAppCollectionViewCell: UICollectionViewCell {
    let view = DAppView()

    private var viewModel: LoadableViewModelState<DAppView.Model>?
    var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            view.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func setupStyle() {
        let selectionView = UIView()
        selectionView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = selectionView
        view.arrowView.isHidden = true
    }

    func bind(viewModel: LoadableViewModelState<DAppView.Model>) {
        self.viewModel = viewModel
        updateLoadingState()
        viewModel.value.map(view.bind)
    }
}

extension DAppCollectionViewCell: AnimationUpdatibleView {
    func updateLayerAnimationIfActive() {
        if viewModel?.isLoading == true {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }
}

extension DAppCollectionViewCell: SkeletonableViewCell, SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [
            view.iconImageView,
            view.titleView
        ]
    }

    func updateLoadingState() {
        if viewModel?.isLoading == false {
            stopLoadingIfNeeded()
        } else {
            startLoadingIfNeeded()
        }
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let iconSize = CGSize(width: DAppView.Constants.iconWidth, height: DAppView.Constants.iconWidth)
        let titleSize = CGSize(width: 66, height: 12)
        let subtitleSize = CGSize(width: 120, height: 8)

        let iconOffset = CGPoint(
            x: contentInsets.left,
            y: contentInsets.top
        )

        let iconSkeleton = SingleSkeleton.createRow(
            on: view,
            containerView: view,
            spaceSize: spaceSize,
            offset: iconOffset,
            size: iconSize,
            cornerRadii: .init(width: 0.25, height: 0.25)
        )

        let titleOffset = CGPoint(
            x: iconOffset.x + iconSize.width + DAppView.Constants.horizontalSpace,
            y: iconOffset.y + 8
        )

        let titleSkeleton = SingleSkeleton.createRow(
            on: view,
            containerView: view,
            spaceSize: spaceSize,
            offset: titleOffset,
            size: titleSize
        )

        let subtitleOffset = CGPoint(
            x: titleOffset.x,
            y: titleOffset.y + titleSize.height + 10
        )

        let subtitleSkeleton = SingleSkeleton.createRow(
            on: view,
            containerView: view,
            spaceSize: spaceSize,
            offset: subtitleOffset,
            size: subtitleSize
        )

        return [iconSkeleton, titleSkeleton, subtitleSkeleton]
    }
}
