import UIKit
import UIKit_iOS
import SnapKit

typealias SwipeGovBannerTableViewCell = PlainBaseTableViewCell<SwipeGovBannerView>

extension PlainBaseTableViewCell where C == SwipeGovBannerView {
    func setupStyle() {
        backgroundColor = .clear
        selectionStyle = .none
    }
}

final class SwipeGovBannerView: UIView {
    let gradientBackgroundView: RoundedGradientBackgroundView = .create { view in
        view.cornerRadius = Constants.cornerRadius
        view.strokeWidth = Constants.strokeWidth
        view.strokeColor = R.color.colorContainerBorder()!
        view.shadowColor = UIColor.black
        view.shadowOpacity = Constants.shadowOpacity
        view.shadowOffset = Constants.shadowOffset
        view.bind(model: .swipeGovCell())
    }

    let contentView = SwipeGovBannerContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension SwipeGovBannerView {
    func setupLayout() {
        addSubview(gradientBackgroundView)
        gradientBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(Constants.verticalInset)
        }
    }
}

// MARK: - Internal

extension SwipeGovBannerView {
    func bind(with viewModel: SwipeGovBannerViewModel) {
        contentView.bind(with: viewModel)
    }
}

// MARK: - Constants

private extension SwipeGovBannerView {
    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let strokeWidth: CGFloat = 2
        static let shadowOpacity: Float = 0.16
        static let shadowOffset = CGSize(width: 6, height: 4)
        static let verticalInset: CGFloat = 15
    }
}
