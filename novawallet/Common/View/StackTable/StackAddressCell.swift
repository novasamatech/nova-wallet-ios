import Foundation
import UIKit_iOS

final class StackAddressCell: RowView<LoadableIconDetailsView> {
    var titleView: LoadableIconDetailsView { rowContentView }

    var skeletonView: SkrullableView?

    var isLoading: Bool = false

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    func bind(viewModel: LoadableViewModelState<DisplayAddressViewModel>) {
        stopLoadingIfNeeded()

        switch viewModel {
        case let .cached(addressViewModel), let .loaded(addressViewModel):
            titleView.detailsLabel.lineBreakMode = addressViewModel.lineBreakMode
            titleView.bind(viewModel: addressViewModel.cellViewModel)
        case .loading:
            startLoadingIfNeeded()
        }
    }

    private func configure() {
        titleView.detailsLabel.apply(style: .regularSubhedlinePrimary)

        titleView.mode = .iconDetails
        titleView.spacing = 12
        titleView.iconWidth = 24
        titleView.imageView.contentMode = .scaleAspectFit
        titleView.detailsLabel.numberOfLines = 1
    }
}

extension StackAddressCell: StackTableViewCellProtocol {}

extension StackAddressCell: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [titleView]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: contentInsets.left, y: 10),
                size: CGSize(width: 24, height: 24)
            ),

            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: contentInsets.left + 36, y: 17),
                size: CGSize(width: 135, height: 10)
            )
        ]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

extension StackAddressCell: SkeletonLoadable {
    func didDisappearSkeleton() {
        if isLoading {
            skeletonView?.stopSkrulling()
        }
    }

    func didAppearSkeleton() {
        if isLoading {
            skeletonView?.restartSkrulling()
        }
    }

    func didUpdateSkeletonLayout() {
        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }
}
