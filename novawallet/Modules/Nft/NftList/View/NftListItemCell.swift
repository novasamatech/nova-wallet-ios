import UIKit
import SoraUI

class NftListItemCell: UICollectionViewCell {
    private enum Constants {
        static let imageHeight = 154.0
        static let imageCornerRadius: CGFloat = 8.0
        static let imageHorizontalInset: CGFloat = 6.0
    }

    let blurBackgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        view.overlayView.highlightedFillColor = R.color.colorHighlightedAccent()!
        return view
    }()

    let mediaView: NftMediaView = {
        let view = NftMediaView()
        view.contentInsets = .zero
        view.contentView.contentMode = .scaleAspectFill
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

    let subtitleView: BorderedLabelView = {
        let view = BorderedLabelView()
        view.titleLabel.textColor = R.color.colorTransparentText()!
        view.titleLabel.font = .semiBoldSmall
        view.contentInsets = UIEdgeInsets(top: 1, left: 6.0, bottom: 2.0, right: 6.0)
        view.backgroundView.cornerRadius = 4.0
        return view
    }()

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                blurBackgroundView.set(highlighted: true, animated: false)
            } else {
                blurBackgroundView.set(highlighted: false, animated: oldValue)
            }
        }
    }

    private var viewModel: NftListViewModel?

    private var preferredWidth: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    func bind(viewModel: NftListViewModel, preferredWidth: CGFloat) {
        self.viewModel?.metadataViewModel.cancel(on: self)
        self.viewModel = viewModel
        self.preferredWidth = preferredWidth

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
            make.top.equalToSuperview().inset(6)
            make.leading.trailing.equalToSuperview().inset(Constants.imageHorizontalInset)
            make.height.equalTo(Constants.imageHeight)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8.0)
            make.top.equalTo(mediaView.snp.bottom).offset(12.0)
        }

        contentView.addSubview(subtitleView)
        subtitleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(8.0)
            make.trailing.lessThanOrEqualToSuperview().inset(8.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(6.0)
        }
    }
}

extension NftListItemCell: NftListItemViewProtocol {
    func setName(_ name: String?) {
        titleLabel.text = name
    }

    func setLabel(_ label: String?) {
        subtitleView.titleLabel.text = label?.uppercased()

        let shouldHideSubtitle = label == nil
        subtitleView.isHidden = shouldHideSubtitle
    }

    func setMedia(_ media: NftMediaViewModelProtocol?) {
        if let media = media, let preferredWidth = preferredWidth {
            let imageWidth = preferredWidth - 2 * Constants.imageHorizontalInset
            let imageSize = CGSize(width: imageWidth, height: Constants.imageHeight)
            mediaView.bind(viewModel: media, targetSize: imageSize, cornerRadius: Constants.imageCornerRadius)
        } else {
            mediaView.bindPlaceholder()
        }
    }
}
