import UIKit
import UIKit_iOS

final class SwapTokenSelectChipView: UIControl {
    let backgroundView: RoundedView = .create { view in
        view.shadowOpacity = 0
        view.cornerRadius = Constants.height / 2
        view.isUserInteractionEnabled = false
    }

    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldFootnotePrimary)
    }

    private let contentStackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = Constants.iconSpacing
        view.isUserInteractionEnabled = false
    }

    private(set) var kind: SwapTokenSelectChipViewModel.Kind = .all
    private var iconViewModel: ImageViewModelProtocol?

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? Constants.highlightedAlpha : 1
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SwapTokenSelectChipViewModel) {
        kind = viewModel.kind
        titleLabel.text = viewModel.title

        applySelection(viewModel.isSelected)
        bindIcon(viewModel.icon, kind: viewModel.kind)
    }
}

// MARK: Private

private extension SwapTokenSelectChipView {
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(Constants.height)
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentStackView.addArrangedSubview(iconView)
        contentStackView.addArrangedSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.networkIconSize)
        }
    }

    func applySelection(_ isSelected: Bool) {
        if isSelected {
            backgroundView.fillColor = R.color.colorButtonBackgroundPrimary()!
            backgroundView.strokeColor = .clear
            backgroundView.strokeWidth = 0
        } else {
            backgroundView.fillColor = R.color.colorChipsBackground()!
            backgroundView.strokeColor = R.color.colorContainerBorder()!
            backgroundView.strokeWidth = Constants.borderWidth
        }

        backgroundView.highlightedFillColor = backgroundView.fillColor
        backgroundView.highlightedStrokeColor = backgroundView.strokeColor
    }

    func bindIcon(_ viewModel: ImageViewModelProtocol?, kind: SwapTokenSelectChipViewModel.Kind) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel
        iconView.image = nil

        iconView.isHidden = viewModel == nil

        let iconSize = kind == .more ? Constants.moreIconSize : Constants.networkIconSize

        iconView.snp.updateConstraints { make in
            make.size.equalTo(iconSize)
        }

        viewModel?.loadImage(
            on: iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: false
        )
    }
}

// MARK: Constants

private extension SwapTokenSelectChipView {
    enum Constants {
        static let height: CGFloat = 36
        static let horizontalInset: CGFloat = 12
        static let iconSpacing: CGFloat = 6
        static let networkIconSize: CGFloat = 16
        static let moreIconSize: CGFloat = 18
        static let borderWidth: CGFloat = 1
        static let highlightedAlpha: CGFloat = 0.6
    }
}
