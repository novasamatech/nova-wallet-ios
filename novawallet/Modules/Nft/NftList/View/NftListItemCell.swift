import UIKit
import SoraUI

class NftListItemCell: UICollectionViewCell {
    private enum Constants {
        static let imageSize = CGSize(width: 154.0, height: 154.0)
        static let imageCornerRadius: CGFloat = 8.0
    }

    let blurBackgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        return view
    }()

    let mediaView: NftMediaView = {
        let view = NftMediaView()
        view.contentInsets = .zero
        view.applyFilledBackgroundStyle()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSubheadline
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSmall
        return label
    }()

    let subtitleBackgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorWhite16()!
        view.highlightedFillColor = R.color.colorWhite16()!
        view.cornerRadius = 4.0
        return view
    }()

    private var viewModel: NftListViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    func bind(viewModel: NftListViewModel) {
        self.viewModel?.metadataViewModel.cancel(on: self)
        self.viewModel = viewModel

        self.viewModel?.metadataViewModel.load(on: self, completion: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(blurBackgroundView)
        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addSubview(mediaView)
        mediaView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(6.0)
            make.size.equalTo(Constants.imageSize)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8.0)
            make.top.equalTo(mediaView.snp.bottom).offset(12.0)
        }

        contentView.addSubview(subtitleBackgroundView)
        subtitleBackgroundView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(8.0)
            make.trailing.lessThanOrEqualToSuperview().inset(8.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
        }

        subtitleBackgroundView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(6.0)
            make.top.bottom.equalToSuperview().inset(1.0)
        }
    }
}

extension NftListItemCell: NftListItemViewProtocol {
    func setName(_ name: String?) {
        titleLabel.text = name
    }

    func setLabel(_ label: String?) {
        subtitleLabel.text = label
    }

    func setMedia(_ media: NftMediaViewModelProtocol?) {
        if let media = media {
            mediaView.bind(viewModel: media, targetSize: Constants.imageSize, cornerRadius: Constants.imageCornerRadius)
        }
    }
}
