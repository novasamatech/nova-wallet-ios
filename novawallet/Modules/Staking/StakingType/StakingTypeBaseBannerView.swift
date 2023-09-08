import SoraUI

class StakingTypeBaseBannerView: UIView {
    let backgroundView: RoundedView = .create {
        $0.cornerRadius = 12
        $0.roundingCorners = .allCorners
        $0.fillColor = R.color.colorSecondaryScreenBackground()!
        $0.highlightedFillColor = R.color.colorSecondaryScreenBackground()!
        $0.strokeWidth = Constants.borderWidth
        $0.shadowOpacity = 0
        $0.strokeColor = R.color.colorStakingTypeCardBorder()!
        $0.highlightedStrokeColor = R.color.colorActiveBorder()!
    }

    let imageView = UIImageView()

    var imageOffsets = Constants.imageOffsets {
        didSet {
            updateImageConstraints()
        }
    }

    var imageSize = Constants.imageSize {
        didSet {
            updateImageConstraints()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(imageOffsets.right)
            $0.top.equalToSuperview().offset(imageOffsets.top)
            $0.size.equalTo(imageSize)
        }

        layer.cornerRadius = 12
    }

    private func updateImageConstraints() {
        imageView.snp.updateConstraints {
            $0.trailing.equalToSuperview().offset(imageOffsets.right)
            $0.top.equalToSuperview().offset(imageOffsets.top)
            $0.size.equalTo(imageSize)
        }
    }
}

extension StakingTypeBaseBannerView {
    private enum Constants {
        static let imageOffsets: (top: CGFloat, right: CGFloat) = (top: -18, right: 26)
        static let imageSize: CGSize = .init(width: 125, height: 111)
        static let borderWidth: CGFloat = 1
    }
}
