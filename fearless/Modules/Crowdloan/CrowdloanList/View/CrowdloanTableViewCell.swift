import UIKit

final class CrowdloanTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = R.color.colorTransparentText()
        label.font = .p2Paragraph
        return label
    }()

    let progressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        return label
    }()

    let progressBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlurSeparator()
        view.layer.cornerRadius = 2
        return view
    }()

    let progressView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 2
        view.backgroundColor = R.color.colorCoral()
        return view
    }()

    private var progressValue: Double?

    let percentsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        return label
    }()

    let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p3Paragraph
        label.textAlignment = .right
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
        separatorInset = .zero

        selectedBackgroundView = UIView()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var viewModel: CrowdloanCellViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.iconViewModel.cancel(on: iconImageView)
        viewModel = nil
        progressValue = nil

        iconImageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let value = progressValue else {
            progressView.frame = .zero
            return
        }

        progressView.frame = .init(
            origin: .zero,
            size: CGSize(
                width: progressBackgroundView.bounds.width * CGFloat(value),
                height: progressBackgroundView.bounds.height
            )
        )
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 8,
            [
                .hStack(
                    alignment: .top,
                    spacing: 12,
                    [
                        iconImageView,
                        .vStack(
                            alignment: .leading,
                            [
                                titleLabel,
                                detailsLabel
                            ]
                        ),
                        navigationImageView
                    ]
                ),
                .hStack([progressLabel, UIView()]),
                progressBackgroundView,
                .hStack([percentsLabel, UIView(), timeLabel])
            ]
        )

        iconImageView.snp.makeConstraints { $0.size.equalTo(32) }
        navigationImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
        progressBackgroundView.addSubview(progressView)
        progressBackgroundView.snp.makeConstraints { $0.height.equalTo(5) }

        let background = TriangularedBlurView()
        background.isUserInteractionEnabled = false
        contentView.addSubview(background)
        background.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(8)
            make.bottom.equalToSuperview()
        }

        background.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(12)
        }
    }

    func bind(viewModel: CrowdloanCellViewModel) {
        self.viewModel = viewModel

        viewModel.iconViewModel.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true
        )

        titleLabel.text = viewModel.title

        switch viewModel.description {
        case let .address(address):
            detailsLabel.text = address
        case let .text(text):
            detailsLabel.text = text
        }

        progressLabel.text = viewModel.progress
        percentsLabel.text = viewModel.progressPercentsText
        progressValue = viewModel.progressValue
        setNeedsLayout()

        if let time = viewModel.timeleft {
            timeLabel.text = time
            percentsLabel.textColor = R.color.colorCoral()
            navigationImageView.isHidden = false
        } else {
            timeLabel.text = nil
            percentsLabel.textColor = R.color.colorTransparentText()
            navigationImageView.isHidden = true
        }
    }
}
