import UIKit
import UIKit_iOS

class SwapReviewDetailsCell<V: UIView>: RowView<SwapGenericInfoView<GenericPairValueView<V, UIImageView>>>,
    StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleButton }
    var valueContentView: V { rowContentView.valueView.fView }
    var accessoryImageView: UIImageView { rowContentView.valueView.sView }

    var showsInfo: Bool {
        get {
            rowContentView.selectable
        }

        set {
            rowContentView.selectable = newValue
        }
    }

    var showsAccessory: Bool {
        get {
            !accessoryImageView.isHidden
        }

        set {
            accessoryImageView.isHidden = !newValue
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func configure() {
        titleButton.imageWithTitleView?.spacingBetweenLabelAndIcon = SwapReviewDetailsConstants.infoSpacing

        rowContentView.valueView.setHorizontalAndSpacing(SwapReviewDetailsConstants.accessorySpacing)
        rowContentView.valueView.stackView.alignment = .center

        accessoryImageView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
        accessoryImageView.contentMode = .scaleAspectFit
        accessoryImageView.snp.makeConstraints {
            $0.size.equalTo(SwapReviewDetailsConstants.accessorySize)
        }

        showsAccessory = false
    }
}

final class SwapReviewTextCell: SwapReviewDetailsCell<UILabel> {
    var valueLabel: UILabel { valueContentView }

    override func configure() {
        super.configure()

        valueLabel.apply(style: .footnotePrimary)
        valueLabel.textAlignment = .right
    }

    func bind(loadableViewModel: LoadableViewModelState<String>) {
        switch loadableViewModel {
        case let .cached(value), let .loaded(value):
            rowContentView.stopLoadingIfNeeded()
            valueLabel.text = value
        case .loading:
            rowContentView.startLoadingIfNeeded()
        }
    }

    func bind(loadableFeeViewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        bind(loadableViewModel: loadableFeeViewModel.map(with: { $0.balanceViewModel.amount }))
    }
}

final class SwapReviewRouteCell: SwapReviewDetailsCell<SwapRouteView> {
    var routeView: SwapRouteView { valueContentView }

    func bind(loadableRouteViewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        switch loadableRouteViewModel {
        case let .cached(value), let .loaded(value):
            rowContentView.stopLoadingIfNeeded()

            routeView.bind(
                items: value,
                itemStyle: .init(iconSize: SwapReviewDetailsConstants.routeIconSize),
                separatorStyle: R.image.iconForward()
            )
        case .loading:
            rowContentView.startLoadingIfNeeded()
        }
    }
}

final class SwapReviewAccountCell: SwapReviewDetailsCell<IconDetailsView> {
    var detailsView: IconDetailsView { valueContentView }

    private var iconViewModel: ImageViewModelProtocol?

    override func configure() {
        super.configure()

        showsInfo = false

        detailsView.mode = .iconDetails
        detailsView.iconWidth = SwapReviewDetailsConstants.accountIconSize
        detailsView.spacing = SwapReviewDetailsConstants.accountIconSpacing
        detailsView.detailsLabel.apply(style: .footnotePrimary)
        detailsView.detailsLabel.numberOfLines = 1
    }

    func bind(details: String, iconViewModel: ImageViewModelProtocol?) {
        self.iconViewModel?.cancel(on: detailsView.imageView)
        self.iconViewModel = iconViewModel

        detailsView.imageView.image = nil
        detailsView.imageView.isHidden = iconViewModel == nil
        detailsView.detailsLabel.text = details

        let size = SwapReviewDetailsConstants.accountIconSize

        iconViewModel?.loadImage(
            on: detailsView.imageView,
            targetSize: CGSize(width: size, height: size),
            animated: true
        )
    }
}

extension StackTableView {
    static func createSwapReviewCard() -> StackTableView {
        let view = StackTableView()
        view.apply(style: .swapReviewCard)
        view.cellHeight = SwapReviewDetailsConstants.rowHeight
        view.hasSeparators = false
        view.contentInsets = SwapReviewDetailsConstants.cardInsets
        return view
    }
}

enum SwapReviewDetailsConstants {
    static let rowHeight: CGFloat = 44
    static let cardInsets = UIEdgeInsets(top: 1, left: 13, bottom: 1, right: 13)
    static let infoSpacing: CGFloat = 8
    static let accessorySpacing: CGFloat = 12
    static let accessorySize: CGFloat = 16
    static let routeIconSize: CGFloat = 20
    static let accountIconSize: CGFloat = 16
    static let accountIconSpacing: CGFloat = 8
}
