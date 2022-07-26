import Foundation
import UIKit

class WalletsListTableViewCell: UITableViewCell {
    private struct Constants {
        static let iconSize: CGFloat = 32.0
    }

    let iconImageView = UIImageView()

    let infoView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.font = .regularSubheadline
        view.valueTop.textAlignment = .left
        view.valueBottom.textColor = R.color.colorTransparentText()
        view.valueBottom.font = .regularFootnote
        view.valueBottom.textAlignment = .left
        view.spacing = 0.0
        return view
    }()

    private var viewModel: WalletsListViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.icon?.cancel(on: iconImageView)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let backgroundView = UIView()
        backgroundView.backgroundColor = R.color.colorHighlightedAccent()
        self.selectedBackgroundView = backgroundView

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletsListViewModel) {
        self.viewModel?.icon?.cancel(on: iconImageView)

        self.viewModel = viewModel

        let targetSize = CGSize(width: Constants.iconSize, height: Constants.iconSize)
        viewModel.icon?.loadImage(on: iconImageView, targetSize: targetSize, animated: true)

        infoView.valueTop.text = viewModel.name
        infoView.valueBottom.text = viewModel.value ?? ""
    }

    func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.centerY.equalToSuperview()
        }
    }
}
