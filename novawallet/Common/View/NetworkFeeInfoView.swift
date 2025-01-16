import Foundation
import UIKit
import UIKit_iOS
import Kingfisher

final class NetworkFeeInfoView: GenericTitleValueView<RoundedButton, GenericPairValueView<RoundedButton, UILabel>>,
    SkeletonableView {
    var titleButton: RoundedButton { titleView }
    var valueTopButton: RoundedButton { valueView.fView }
    var valueBottomLabel: UILabel { valueView.sView }
    var skeletonView: SkrullableView?
    private lazy var iconPencil = R.image.iconPencilEdit()!

    private var isLoading: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func hideInfoIcon() {
        titleButton.imageWithTitleView?.iconImage = nil
    }

    private func configure() {
        titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        titleButton.imageWithTitleView?.titleFont = .regularFootnote
        titleButton.imageWithTitleView?.iconImage = R.image.iconInfoFilled()
        titleButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        titleButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        titleButton.applyIconStyle()
        titleButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        valueTopButton.applyIconStyle()
        valueTopButton.imageWithTitleView?.iconImage = iconPencil
        valueTopButton.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        valueTopButton.imageWithTitleView?.titleFont = .regularFootnote
        valueTopButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 6
        valueTopButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        valueBottomLabel.textColor = R.color.colorTextSecondary()
        valueBottomLabel.font = .caption1
        valueBottomLabel.textAlignment = .right

        valueView.makeVertical()
        valueTopButton.contentInsets = .zero
    }
}

extension NetworkFeeInfoView {
    func bind(viewModel: NetworkFeeInfoViewModel) {
        valueTopButton.imageWithTitleView?.iconImage = viewModel.isEditable ? iconPencil : nil
        valueTopButton.isUserInteractionEnabled = viewModel.isEditable
        valueTopButton.imageWithTitleView?.title = viewModel.balanceViewModel.amount
        valueBottomLabel.text = viewModel.balanceViewModel.price
        valueTopButton.invalidateLayout()
    }

    func bind(loadableViewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        switch loadableViewModel {
        case let .cached(value), let .loaded(value):
            isLoading = false
            stopLoadingIfNeeded()
            bind(viewModel: value)
        case .loading:
            isLoading = true
            startLoadingIfNeeded()
        }
    }
}

extension NetworkFeeInfoView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let size = CGSize(width: 68, height: 8)
        let offset = CGPoint(
            x: spaceSize.width - size.width,
            y: spaceSize.height / 2.0 - size.height / 2.0
        )

        let row = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: offset,
            size: size
        )

        return [row]
    }

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [valueView]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}
