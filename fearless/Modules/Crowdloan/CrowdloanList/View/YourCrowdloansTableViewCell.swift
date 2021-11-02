import UIKit

final class YourCrowdloansTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let navigationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrow()
        imageView.contentMode = .center
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let blurView = TriangularedBlurView()
        blurView.isUserInteractionEnabled = false
        contentView.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        let content = UIView.hStack(
            spacing: 10,
            [
                titleLabel, UIView(), countLabel, navigationImageView
            ]
        )
        navigationImageView.snp.makeConstraints { $0.size.equalTo(16) }

        blurView.addSubview(content)
        content.snp.makeConstraints { make in
            make.bottom.top.equalToSuperview().inset(20)
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().inset(20)
        }
    }

    func bind(title: String, count: Int) {
        titleLabel.text = title
        countLabel.text = count.description
    }
}
