import Foundation
import UIKit
import UIKit_iOS

final class StackTitleMultiValueCell: RowView<GenericTitleValueView<IconDetailsView, MultiValueView>>, SkeletonableView {
    var titleLabel: UILabel { rowContentView.titleView.detailsLabel }
    var topValueLabel: UILabel { rowContentView.valueView.valueTop }
    var bottomValueLabel: UILabel { rowContentView.valueView.valueBottom }
    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    var canSelect: Bool = true {
        didSet {
            if oldValue != canSelect {
                updateSelection()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateSelection() {
        if canSelect {
            isUserInteractionEnabled = true
            rowContentView.titleView.imageView.image = R.image.iconInfoFilled()
        } else {
            isUserInteractionEnabled = false
            rowContentView.titleView.imageView.image = nil
        }
    }

    private func configure() {
        titleLabel.textColor = R.color.colorTextSecondary()
        titleLabel.font = .regularFootnote

        rowContentView.titleView.mode = .detailsIcon
        rowContentView.titleView.spacing = 4.0

        topValueLabel.textColor = R.color.colorTextPrimary()
        topValueLabel.font = .regularFootnote
        bottomValueLabel.textColor = R.color.colorTextSecondary()
        bottomValueLabel.font = .caption1

        borderView.strokeColor = R.color.colorDivider()!

        updateSelection()
    }
}

extension StackTitleMultiValueCell: StackTableViewCellProtocol {}

extension StackTitleMultiValueCell {
    func bind(viewModel: BalanceViewModelProtocol) {
        rowContentView.valueView.bind(
            topValue: viewModel.amount,
            bottomValue: viewModel.price
        )
    }

    func bind(loadableViewModel: LoadableViewModelState<String>) {
        switch loadableViewModel {
        case let .cached(value), let .loaded(value):
            isLoading = false
            rowContentView.valueView.valueTop.text = value
            invalidateLayout()
        case .loading:
            isLoading = true
            invalidateLayout()
        }
    }
}

extension StackTitleMultiValueCell {
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
        [rowContentView.valueView]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}
