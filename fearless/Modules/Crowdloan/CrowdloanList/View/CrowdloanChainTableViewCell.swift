import UIKit

final class CrowdloanChainTableViewCell: UITableViewCell {
    let chainSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()!
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        return label
    }()

    private var viewModel: CrowdloansChainViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.imageViewModel?.cancel(on: chainSelectionView.iconView)
    }

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

    func bind(viewModel: CrowdloansChainViewModel) {
        self.viewModel?.imageViewModel?.cancel(on: chainSelectionView.iconView)
        chainSelectionView.iconView.image = nil

        self.viewModel = viewModel

        chainSelectionView.title = viewModel.networkName
        chainSelectionView.subtitle = viewModel.balance

        let iconSize = 2 * chainSelectionView.iconRadius
        viewModel.imageViewModel?.loadImage(
            on: chainSelectionView.iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )

        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description
    }

    private func setupLayout() {
        let chainBlur = TriangularedBlurView()
        contentView.addSubview(chainBlur)
        chainBlur.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(16)
        }

        chainBlur.addSubview(chainSelectionView)
        chainSelectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(48.0)
        }

        let textBlur = TriangularedBlurView()
        contentView.addSubview(textBlur)
        textBlur.snp.makeConstraints { make in
            make.top.equalTo(chainBlur.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        let labelsContent = UIView.vStack(
            alignment: .leading,
            spacing: 12,
            [titleLabel, descriptionLabel]
        )

        textBlur.addSubview(labelsContent)
        labelsContent.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}
