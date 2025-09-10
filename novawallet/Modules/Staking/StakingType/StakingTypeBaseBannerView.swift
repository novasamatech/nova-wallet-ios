import UIKit
import UIKit_iOS

class StakingTypeBaseBannerView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()

        view.cornerRadius = 12
        view.roundingCorners = .allCorners
        view.fillColor = .black
        view.highlightedFillColor = .black

        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let imageView = UIImageView()

    let borderView: RoundedView = .create { view in
        view.applyStrokedBackgroundStyle()
        view.cornerRadius = 12
        view.roundingCorners = .allCorners

        view.strokeWidth = Constants.borderWidth
        view.strokeColor = R.color.colorStakingTypeCardBorder()!
        view.highlightedStrokeColor = R.color.colorActiveBorder()!
    }

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

        backgroundView.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(imageOffsets.right)
            $0.top.equalToSuperview().offset(imageOffsets.top)
            $0.size.equalTo(imageSize)
        }

        addSubview(borderView)
        borderView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
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
