import SnapKit
import UIKit
import UIKit_iOS

class SubtensorSubnetCardCell: UITableViewCell {
    static let cardHeight: CGFloat = 64
    static let preferredHeight: CGFloat = cardHeight + 8

    let cardView: UIView = .create { view in
        view.backgroundColor = R.color.colorBlockBackground()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview()
            make.height.equalTo(Self.cardHeight)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        cardView.backgroundColor = highlighted ? R.color.colorCellBackgroundPressed() : R.color.colorBlockBackground()
    }
}

final class SubtensorSubnetRootCell: SubtensorSubnetCardCell {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldSubhedlinePrimary)
    }

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconLinkChevron()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .scaleAspectFit
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        [iconView, titleLabel, chevronView].forEach(cardView.addSubview)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.iconInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(SubtensorSubnetCell.Constants.iconSize)
        }

        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(SubtensorSubnetCell.Constants.contentInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.chevronSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(SubtensorSubnetCell.Constants.contentSpacing)
            make.trailing.lessThanOrEqualTo(chevronView.snp.leading)
                .offset(-SubtensorSubnetCell.Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, icon: ImageViewModelProtocol?) {
        titleLabel.text = title

        iconViewModel?.cancel(on: iconView)
        iconViewModel = icon

        let size = SubtensorSubnetCell.Constants.iconSize
        icon?.loadImage(on: iconView, targetSize: CGSize(width: size, height: size), animated: false)
    }

    private enum Constants {
        static let iconInset: CGFloat = 16
        static let chevronSize: CGFloat = 20
    }
}
