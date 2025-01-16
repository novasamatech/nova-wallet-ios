import UIKit
import UIKit_iOS

class AssetListAssetCell: UICollectionViewCell {
    private static let iconViewSize: CGFloat = 40.0

    let iconView: AssetIconView = {
        let view = AssetIconView()
        return view
    }()

    let assetLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldBody
        label.textColor = R.color.colorTextPrimary()
        return label
    }()

    let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldBody
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .right
        return label
    }()

    let balanceValueLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .right
        return label
    }()

    let dividerView: BorderedContainerView = .create { view in
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDivider()!
        view.borderType = .bottom

        view.isHidden = true
    }

    let selectedView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorCellBackgroundPressed()!
        view.cornerRadius = 0.0
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let rowView = RowView(contentView: selectedView)
        rowView.isUserInteractionEnabled = false
        rowView.contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = rowView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        dividerView.isHidden = true
    }

    func createDetailsView() -> UIView {
        fatalError("Must be overriden by subsclass")
    }

    func bind(viewModel: AssetListTokenGroupViewModel) {
        bind(
            viewModel: viewModel,
            balanceKeyPath: \.balance,
            imageKeyPath: \.token.imageViewModel,
            nameKeyPath: \.token.symbol
        )

        selectedView.cornerRadius = 8.0
    }

    func configureSelectionView(for expanded: Bool) {
        selectedView.roundingCorners = if expanded {
            [.topLeft, .topRight]
        } else {
            .allCorners
        }
    }

    func showDivider() {
        dividerView.isHidden = false
    }

    func bind<T>(
        viewModel: T,
        balanceKeyPath: KeyPath<T, AssetListAssetBalanceViewModel>,
        imageKeyPath: KeyPath<T, ImageViewModelProtocol?>,
        nameKeyPath: KeyPath<T, String>
    ) {
        iconViewModel?.cancel(on: iconView.imageView)

        iconViewModel = viewModel[keyPath: imageKeyPath]

        iconView.imageView.image = nil

        let iconSize = Self.iconViewSize - iconView.contentInsets.left - iconView.contentInsets.right
        viewModel[keyPath: imageKeyPath]?.loadImage(
            on: iconView.imageView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )

        assetLabel.text = viewModel[keyPath: nameKeyPath]

        let balanceViewModel = viewModel[keyPath: balanceKeyPath]

        applyBalance(balanceViewModel.balanceAmount)
        applyBalanceValue(balanceViewModel.balanceValue)
    }

    private func applyBalance(_ balanceViewModel: LoadableViewModelState<String>) {
        switch balanceViewModel {
        case .loading:
            balanceLabel.text = ""
        case let .cached(value), let .loaded(value):
            balanceLabel.attributedText = NSAttributedString.styledAmountString(
                from: value,
                intPartFont: .semiBoldBody,
                fractionFont: .semiBoldSubheadline,
                decimalSeparator: String(String.Separator.dot.rawValue)
            )
        }
    }

    private func applyBalanceValue(_ balanceValueViewModel: LoadableViewModelState<String>) {
        switch balanceValueViewModel {
        case .loading:
            balanceValueLabel.text = ""
        case let .cached(value):
            balanceValueLabel.text = value
        case let .loaded(value):
            balanceValueLabel.text = value
        }
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(28.0)
            make.top.bottom.equalToSuperview().inset(8.0)
            make.size.equalTo(Self.iconViewSize)
        }

        iconView.backgroundView.cornerRadius = Self.iconViewSize / 2.0

        contentView.addSubview(assetLabel)
        assetLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.top.equalToSuperview().inset(8.0)
        }

        let detailsView = createDetailsView()

        contentView.addSubview(detailsView)
        detailsView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.bottom.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.leading.greaterThanOrEqualTo(assetLabel.snp.trailing).offset(4.0)
            make.top.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(balanceValueLabel)
        balanceValueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.leading.greaterThanOrEqualTo(detailsView.snp.trailing).offset(4.0)
            make.bottom.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(dividerView)
        dividerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
        }
    }
}
