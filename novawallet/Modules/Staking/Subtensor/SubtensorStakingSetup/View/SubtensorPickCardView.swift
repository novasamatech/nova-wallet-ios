import UIKit
import UIKit_iOS

final class SubtensorPickCardView: UIView {
    let headerView = SubtensorPickCardHeaderView()

    let chipsView = SubtensorFactChipsView()

    let rowsView: StackTableView = .create { view in
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.contentInsets = .zero
    }

    let validatorCell = SubtensorPickValidatorCell()
    let browseView = SubtensorBrowseLinkView()

    let receiveCell = SubtensorPickCardView.createValueCell()

    let swapRateCell = SubtensorPickCardView.createValueCell()

    let networkFeeCell = SubtensorPickCardView.createValueCell()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPickCardViewModel) {
        validatorCell.bind(
            validator: viewModel.validator,
            rate: viewModel.validatorRate,
            isEditable: viewModel.isValidatorEditable
        )
        browseView.bind(title: viewModel.browseTitle)
        headerView.bind(viewModel: viewModel.header)
        chipsView.bind(titles: viewModel.chips)

        receiveCell.apply(viewModel.receive)
        swapRateCell.apply(viewModel.swapRate)
        networkFeeCell.bindPickValue(viewModel.networkFee)

        rowsView.updateLayout()
        let rows: [StackTableViewCellProtocol] = [validatorCell, receiveCell, swapRateCell, networkFeeCell]
        rows.forEach { SubtensorDividerStyle.apply(to: $0, hasPrevious: false) }
        rows.filter { !$0.isHidden }.enumerated().forEach { index, cell in
            SubtensorDividerStyle.apply(to: cell, hasPrevious: index > 0)
        }
    }

    static func createValueCell() -> StackTitleMultiValueCell {
        let cell = StackTitleMultiValueCell()
        cell.canSelect = false
        cell.topValueLabel.apply(style: .semiboldFootnotePrimary)
        cell.bottomValueLabel.apply(style: .semiboldFootnotePrimary)

        [cell.topValueLabel, cell.bottomValueLabel].forEach { label in
            label.snp.makeConstraints { $0.height.equalTo(Constants.valueLineHeight) }
        }

        return cell
    }
}

extension StackTitleMultiValueCell {
    func bindPickValue(_ viewModel: BalanceViewModelProtocol?) {
        if let viewModel {
            stopLoadingIfNeeded()
            bind(viewModel: viewModel)
        } else {
            startLoadingIfNeeded()
        }
    }
}

private extension SubtensorPickCardView {
    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let spacing: CGFloat = 10
        static let padding: CGFloat = 12
        static let valueLineHeight: CGFloat = 18
    }

    func setupLayout() {
        swapRateCell.canSelect = true

        rowsView.addArrangedSubview(validatorCell)
        rowsView.addArrangedSubview(receiveCell)
        rowsView.addArrangedSubview(swapRateCell)
        rowsView.addArrangedSubview(networkFeeCell)

        let cells: [StackTableViewCellProtocol] = [validatorCell, receiveCell, swapRateCell, networkFeeCell]
        cells.forEach { $0.borderView.strokeWidth = SubtensorDividerStyle.thickness }
        let contentView = UIView.vStack(spacing: Constants.spacing, [headerView, chipsView, rowsView, browseView])
        contentView.layoutMargins = UIEdgeInsets(inset: Constants.padding)
        contentView.isLayoutMarginsRelativeArrangement = true

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

final class SubtensorPickCardHeaderView: UIControl {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = Constants.iconSize / 2
        view.clipsToBounds = true
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    let skeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPickCardHeaderViewModel?) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel?.icon
        iconView.image = nil

        viewModel?.icon.loadImage(
            on: iconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: true
        )

        titleLabel.text = viewModel?.title
        chevronView.isHidden = !(viewModel?.isSelectable ?? false)
        isUserInteractionEnabled = viewModel?.isSelectable ?? false

        skeletonView.setLoading(viewModel == nil)
    }
}

private extension SubtensorPickCardHeaderView {
    enum Constants {
        static let iconSize: CGFloat = 36
        static let chevronSize: CGFloat = 20
        static let spacing: CGFloat = 10
    }

    func setupLayout() {
        let labelsView = UIView.vStack(spacing: 2, [titleLabel])
        labelsView.isUserInteractionEnabled = false

        let contentView = UIView.hStack(
            alignment: .center,
            spacing: Constants.spacing,
            [iconView, labelsView, chevronView]
        )
        contentView.isUserInteractionEnabled = false

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        chevronView.snp.makeConstraints { make in
            make.size.equalTo(Constants.chevronSize)
        }

        addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.leading.equalTo(labelsView)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 140, height: 12))
        }
    }
}

final class SubtensorPickCardSkeletonView: UIView, SkeletonableView {
    let receiveTitleLabel = UILabel(style: .footnoteSecondary, numberOfLines: 1)
    let swapRateTitleLabel = UILabel(style: .footnoteSecondary, numberOfLines: 1)
    let networkFeeTitleLabel = UILabel(style: .footnoteSecondary, numberOfLines: 1)
    let captionLabel = UILabel(style: .caption1Secondary)

    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { self }
    var hidingViews: [UIView] { [] }

    private var placeholders: [UIView] = []
    private var isLoading = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true
        isHidden = true

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
        }
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
        isHidden = !loading

        if loading {
            startLoadingIfNeeded()
        } else {
            stopLoadingIfNeeded()
        }
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        placeholders.map { placeholder in
            SingleSkeleton.createRow(
                on: placeholder,
                containerView: self,
                spaceSize: spaceSize,
                offset: .zero,
                size: placeholder.frame.size
            )
        }
    }
}

private extension SubtensorPickCardSkeletonView {
    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let contentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        static let spacing: CGFloat = 10
        static let captionSpacing: CGFloat = 12
        static let captionLineHeight: CGFloat = 16
        static let iconSize = CGSize(width: 36, height: 36)
        static let titleSize = CGSize(width: 140, height: 12)
        static let subtitleSize = CGSize(width: 90, height: 10)
        static let titleSpacing: CGFloat = 2
        static let chipSizes = [96, 72, 110].map { CGSize(width: $0, height: 26) }
        static let chipSpacing: CGFloat = 6
        static let valueSize = CGSize(width: 120, height: 12)
        static let rowHeight: CGFloat = 36
        static let infoSpacing: CGFloat = 4
    }

    func makePlaceholder(_ size: CGSize) -> UIView {
        let view = UIView()
        view.snp.makeConstraints { $0.size.equalTo(size) }
        placeholders.append(view)
        return view
    }

    func makeRow(_ titleLabel: UILabel, hasInfo: Bool = false) -> UIView {
        let infoView = UIImageView(image: R.image.iconInfoFilled())
        infoView.isHidden = !hasInfo
        let titleView = UIView.hStack(alignment: .center, spacing: Constants.infoSpacing, [titleLabel, infoView])
        let row = UIView.hStack(alignment: .center, [titleView, .spacer(), makePlaceholder(Constants.valueSize)])
        row.snp.makeConstraints { $0.height.equalTo(Constants.rowHeight) }
        return row
    }

    func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = R.color.colorDivider()
        view.snp.makeConstraints { $0.height.equalTo(SubtensorDividerStyle.thickness) }
        return view
    }

    func setupLayout() {
        let chevronView = UIImageView(image: R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!))
        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        let titlesView = UIView.vStack(
            alignment: .leading,
            spacing: Constants.titleSpacing,
            [makePlaceholder(Constants.titleSize), makePlaceholder(Constants.subtitleSize)]
        )
        let headerView = UIView.hStack(
            alignment: .center,
            spacing: Constants.spacing,
            [makePlaceholder(Constants.iconSize), titlesView, chevronView]
        )
        let chipsView = UIView.hStack(
            spacing: Constants.chipSpacing,
            Constants.chipSizes.map { makePlaceholder($0) } + [.spacer()]
        )
        let rowsView = UIView.vStack([
            makeRow(receiveTitleLabel),
            makeDivider(),
            makeRow(swapRateTitleLabel, hasInfo: true),
            makeDivider(),
            makeRow(networkFeeTitleLabel)
        ])
        let contentView = UIView.vStack(
            spacing: Constants.spacing,
            margins: Constants.contentInsets,
            [headerView, chipsView, rowsView, captionLabel]
        )
        contentView.setCustomSpacing(Constants.captionSpacing, after: rowsView)

        addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

extension SubtensorPickCardSkeletonView {
    func bind(caption: String) {
        captionLabel.apply(text: caption, lineHeight: Constants.captionLineHeight)
    }
}

final class SubtensorBrowseLinkView: UIView {
    let button: RoundedButton = .create { button in
        button.applyLinkStyle()
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = Constants.iconSpacing
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(button)
        button.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.topInset)
            make.trailing.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.height.equalTo(Constants.height)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String?) {
        button.setTitle(title)
        isHidden = title == nil
    }
}

private extension SubtensorBrowseLinkView {
    enum Constants {
        static let topInset: CGFloat = 2
        static let height: CGFloat = 18
        static let iconSpacing: CGFloat = 2
    }
}
