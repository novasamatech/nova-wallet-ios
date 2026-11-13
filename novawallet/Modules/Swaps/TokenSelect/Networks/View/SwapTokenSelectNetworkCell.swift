import UIKit

final class SwapTokenSelectNetworkCell: UITableViewCell {
    let networkIconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let nameLabel: UILabel = .create { view in
        view.apply(style: .regularBodyPrimary)
    }

    let checkboxView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        let selectedView = UIView()
        selectedView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = selectedView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        iconViewModel?.cancel(on: networkIconView)
        iconViewModel = nil
        networkIconView.image = nil
    }

    func bind(viewModel: SwapTokenSelectNetworkViewModel) {
        iconViewModel?.cancel(on: networkIconView)
        iconViewModel = viewModel.network.icon
        networkIconView.image = nil

        viewModel.network.icon?.loadImage(
            on: networkIconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: false
        )

        nameLabel.text = viewModel.network.name

        checkboxView.image = viewModel.isSelected ? R.image.iconCheckbox() : R.image.iconCheckboxEmpty()
    }
}

// MARK: Private

private extension SwapTokenSelectNetworkCell {
    func setupLayout() {
        contentView.addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        contentView.addSubview(checkboxView)
        checkboxView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.checkboxSize)
        }

        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.nameOffset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(checkboxView.snp.leading).offset(-Constants.nameOffset)
        }
    }
}

// MARK: Constants

extension SwapTokenSelectNetworkCell {
    enum Constants {
        static let height: CGFloat = 56
        static let iconSize: CGFloat = 32
        static let checkboxSize: CGFloat = 24
        static let nameOffset: CGFloat = 12
    }
}
