import UIKit

final class NetworksItemCell: UITableViewCell {
    private let networkImageView = UIImageView()

    private let networkNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let nodeLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let arrowImageView = UIImageView(image: R.image.iconSmallArrow())
    private var iconViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()!
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        iconViewModel?.cancel(on: networkImageView)
        iconViewModel = nil
    }

    private func setupLayout() {
        let content: UIView = .hStack(
            alignment: .center,
            distribution: .fillProportionally,
            spacing: 12,
            [
                networkImageView,
                .vStack(
                    [networkNameLabel, nodeLabel]
                ),
                UIView(),
                arrowImageView
            ]
        )
        networkImageView.snp.makeConstraints { $0.size.equalTo(32) }
        arrowImageView.snp.makeConstraints { $0.size.equalTo(24) }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}

extension NetworksItemCell {
    func bind(viewModel: NetworksItemViewModel) {
        networkNameLabel.text = viewModel.name
        nodeLabel.text = viewModel.nodeDescription

        iconViewModel = viewModel.icon
        networkImageView.image = nil
        iconViewModel?.loadImage(
            on: networkImageView,
            targetSize: CGSize(width: 32.0, height: 32.0),
            animated: true
        )
    }
}
