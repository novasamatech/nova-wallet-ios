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

    let receiveCell = SubtensorPickCardView.createCell()

    let swapRateCell = SubtensorPickCardView.createCell()

    let networkFeeCell = SubtensorPickCardView.createCell()

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
        headerView.bind(viewModel: viewModel.header)
        chipsView.bind(titles: viewModel.chips)

        bind(row: viewModel.receive, cell: receiveCell)
        bind(row: viewModel.swapRate, cell: swapRateCell)
        bind(networkFee: viewModel.networkFee)

        rowsView.updateLayout()
    }
}

private extension SubtensorPickCardView {
    enum Constants {
        static let cornerRadius: CGFloat = 12
    }

    static func createCell() -> StackTitleMultiValueCell {
        let cell = StackTitleMultiValueCell()
        cell.canSelect = false
        return cell
    }

    func setupLayout() {
        swapRateCell.canSelect = true

        rowsView.addArrangedSubview(receiveCell)
        rowsView.addArrangedSubview(swapRateCell)
        rowsView.addArrangedSubview(networkFeeCell)

        let contentView = UIView.vStack(spacing: 0, [headerView, chipsView, rowsView])
        contentView.setCustomSpacing(12, after: headerView)
        contentView.setCustomSpacing(4, after: chipsView)
        contentView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 4, right: 16)
        contentView.isLayoutMarginsRelativeArrangement = true

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(row: SubtensorSetupRowViewModel, cell: StackTitleMultiValueCell) {
        cell.isHidden = row == .hidden

        switch row {
        case .hidden:
            cell.stopLoadingIfNeeded()
        case .loading:
            cell.startLoadingIfNeeded()
        case let .value(value):
            cell.stopLoadingIfNeeded()
            cell.rowContentView.valueView.bind(topValue: value, bottomValue: nil)
        }
    }

    func bind(networkFee: BalanceViewModelProtocol?) {
        if let networkFee {
            networkFeeCell.stopLoadingIfNeeded()
            networkFeeCell.bind(viewModel: networkFee)
        } else {
            networkFeeCell.startLoadingIfNeeded()
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
        label.apply(style: .semiboldBodyPrimary)
    }

    let apyLabel: UILabel = .create { label in
        label.apply(style: .footnotePositive)
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .center
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
        apyLabel.text = viewModel?.apy
        apyLabel.isHidden = viewModel?.apy == nil
        chevronView.isHidden = !(viewModel?.isSelectable ?? false)
        isUserInteractionEnabled = viewModel?.isSelectable ?? false

        skeletonView.setLoading(viewModel == nil)
    }
}

private extension SubtensorPickCardHeaderView {
    enum Constants {
        static let iconSize: CGFloat = 32
        static let height: CGFloat = 40
    }

    func setupLayout() {
        let labelsView = UIView.vStack(spacing: 2, [titleLabel, apyLabel])
        labelsView.isUserInteractionEnabled = false

        let contentView = UIView.hStack(alignment: .center, spacing: 12, [iconView, labelsView, chevronView])
        contentView.isUserInteractionEnabled = false

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(Constants.height)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.leading.equalTo(labelsView)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 140, height: 12))
        }
    }
}
