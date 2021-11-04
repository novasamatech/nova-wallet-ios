import UIKit

final class CrowdloanTableHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let chainSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        return view
    }()

    let aboutLabel: UILabel = {
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

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        descriptionLabel.preferredMaxLayoutWidth = descriptionLabel.bounds.width
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

        aboutLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10)
            make.height.equalTo(41)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let chainBlur = TriangularedBlurView()
        addSubview(chainBlur)
        chainBlur.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        chainBlur.addSubview(chainSelectionView)
        chainSelectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(48.0)
        }

        let textBlur = TriangularedBlurView()
        addSubview(textBlur)
        textBlur.snp.makeConstraints { make in
            make.top.equalTo(chainBlur.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        let labelsContent = UIView.vStack(
            spacing: 12,
            [aboutLabel, descriptionLabel]
        )
        aboutLabel.snp.makeConstraints { $0.height.equalTo(20) }

        textBlur.addSubview(labelsContent)
        labelsContent.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}
