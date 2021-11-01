import UIKit

final class CrowdloanYourContributionsCell: UITableViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var iconViewModel: ImageViewModelProtocol?

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p0Paragraph
        return label
    }()

    private let contributedAmountLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p0Paragraph
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        iconViewModel?.cancel(on: iconImageView)
        iconViewModel = nil
        iconImageView.image = nil
    }

    private func setupLayout() {
        let content = UIView.hStack(
            alignment: .center,
            spacing: 12,
            [
                iconImageView, nameLabel, UIView(), contributedAmountLabel
            ]
        )
        iconImageView.snp.makeConstraints { $0.size.equalTo(32) }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(8)
        }
    }

    func bind(viewModel: CrowdloanContributionItem) {
        nameLabel.text = viewModel.name
        contributedAmountLabel.text = viewModel.contributed

        viewModel.iconViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true
        )
        iconViewModel = viewModel.iconViewModel
    }
}
