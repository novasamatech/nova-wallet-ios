import UIKit
import UIKit_iOS

final class SwapDetailsView: UIView {
    let backgroundView: RoundedView = .create {
        $0.applyFilledBackgroundStyle(
            for: R.color.colorBlockBackground()!,
            highlighted: R.color.colorBlockBackground()!
        )
        $0.cornerRadius = Constants.cornerRadius
    }

    let titleControl: ActionTitleControl = .create {
        $0.indicator = ResizableImageActionIndicator(size: Constants.indicatorSize)
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: R.color.colorIconSecondary()!)
        $0.identityIconAngle = CGFloat.pi / 2.0
        $0.activationIconAngle = -CGFloat.pi / 2.0
        $0.titleLabel.apply(style: .footnotePrimary)
        $0.titleLabel.textAlignment = .left
        $0.titleLabel.numberOfLines = 1
        $0.layoutType = .flexible
        $0.horizontalSpacing = 0
        $0.imageView.isUserInteractionEnabled = false
        $0.deactivate(animated: false)
    }

    let titleSeparator: UIView = .create {
        $0.backgroundColor = R.color.colorContainerBorder()
    }

    let rateCell: SwapInfoViewCell = .create {
        SwapDetailsView.configure(cell: $0)
    }

    let routeCell: SwapRouteViewCell = .create {
        SwapDetailsView.configure(cell: $0)
        $0.rowContentView.selectable = false
        $0.itemStyle = .init(iconSize: Constants.routeIconSize)
        $0.separatorStyle = R.image.iconForward()?.tinted(with: R.color.colorIconSecondary()!)
    }

    let execTimeCell: SwapInfoViewCell = .create {
        SwapDetailsView.configure(cell: $0)
        $0.rowContentView.selectable = false
        $0.isUserInteractionEnabled = false
    }

    let networkFeeCell: SwapNetworkFeeViewCell = .create {
        $0.preferredHeight = Constants.rowHeight
        $0.contentInsets = Constants.cellInsets
        $0.borderView.borderType = .none
        $0.roundedBackgroundView.fillColor = .clear
        $0.rowContentView.hideInfoIcon()
        $0.valueTopButton.isUserInteractionEnabled = false
    }

    let priceDifferenceCell: SwapInfoViewCell = .create {
        SwapDetailsView.configure(cell: $0)
    }

    let slippageCell: SwapInfoViewCell = .create {
        SwapDetailsView.configure(cell: $0)
        $0.rowContentView.selectable = false
    }

    let minReceivedCell: SwapInfoViewCell = .create {
        SwapDetailsView.configure(cell: $0)
        $0.rowContentView.selectable = false
        $0.isUserInteractionEnabled = false
    }

    private let rowsView: UIStackView = .create {
        $0.axis = .vertical
        $0.isHidden = true
    }

    var expanded: Bool { titleControl.isActivated }

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setExpanded(_ value: Bool, animated: Bool) {
        if value != titleControl.isActivated {
            if value {
                titleControl.activate(animated: animated)
            } else {
                titleControl.deactivate(animated: animated)
            }
        }

        applyExpansion()
    }

    func applyExpansion() {
        rowsView.isHidden = !expanded
        titleSeparator.isHidden = !expanded
    }

    func setPriceDifferenceVisible(_ isVisible: Bool) {
        priceDifferenceCell.isHidden = !isVisible
    }
}

// MARK: Private

private extension SwapDetailsView {
    static func configure(cell: SwapInfoViewCell) {
        cell.preferredHeight = Constants.rowHeight
        cell.contentInsets = Constants.cellInsets
        cell.borderView.borderType = .none
        cell.roundedBackgroundView.fillColor = .clear
    }

    static func configure(cell: SwapRouteViewCell) {
        cell.preferredHeight = Constants.rowHeight
        cell.contentInsets = Constants.chevronCellInsets
        cell.borderView.borderType = .none
        cell.roundedBackgroundView.fillColor = .clear
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let contentView = UIView.vStack([titleControl, rowsView])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.rowHeight)
        }

        titleControl.contentInsets = Constants.titleInsets

        addSubview(titleSeparator)
        titleSeparator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.bottom.equalTo(titleControl)
            make.height.equalTo(Constants.separatorHeight)
        }

        let rows: [UIView] = [
            rateCell,
            routeCell,
            execTimeCell,
            networkFeeCell,
            priceDifferenceCell,
            slippageCell,
            minReceivedCell
        ]

        rows.forEach { row in
            rowsView.addArrangedSubview(row)

            row.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }
        }

        networkFeeCell.contentInsets = Constants.chevronCellInsets

        [routeCell, networkFeeCell].forEach { addChevron(to: $0) }

        applyExpansion()
    }

    func addChevron(to cell: UIView) {
        let imageView = UIImageView(image: R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!))
        imageView.contentMode = .center
        imageView.isUserInteractionEnabled = false

        cell.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.chevronSize)
        }
    }
}

extension SwapDetailsView {
    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let rowHeight: CGFloat = 44
        static let horizontalInset: CGFloat = 12
        static let separatorHeight: CGFloat = 1
        static let indicatorSize = CGSize(width: 16, height: 16)
        static let routeIconSize: CGFloat = 20
        static let chevronSize = CGSize(width: 24, height: 24)
        static let titleInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        static let cellInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        static let chevronCellInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 44)
    }
}
