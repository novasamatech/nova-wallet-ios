import UIKit
import SnapKit
import UIKit_iOS

final class RoundedIconTitleView: UIView {
    let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.detailsLabel.textColor = R.color.colorTextSecondary()
        view.detailsLabel.font = .semiBoldCaps1
        view.detailsLabel.numberOfLines = 1
        view.mode = .iconDetails
        view.spacing = 6.0
        view.iconWidth = 16.0
        return view
    }()

    var contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0) {
        didSet {
            if contentInsets != oldValue {
                roundedBackgroundView.snp.updateConstraints { make in
                    make.leading.equalToSuperview().inset(contentInsets.left)
                    make.trailing.lessThanOrEqualToSuperview().inset(contentInsets.right)
                    make.top.equalToSuperview().inset(contentInsets.top)
                    make.bottom.equalToSuperview().inset(contentInsets.bottom)
                }
            }
        }
    }

    lazy var roundedBackgroundView: RoundedView = createBackground()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, icon: UIImage?) {
        titleView.detailsLabel.text = title
        titleView.imageView.image = icon

        setNeedsLayout()
    }
}

// MARK: - Private

private extension RoundedIconTitleView {
    func setupLayout() {
        setupBackgroundLayout(
            for: self,
            backgroundView: roundedBackgroundView
        )
        setupContentLayout(
            for: roundedBackgroundView,
            contentView: titleView
        )
    }

    func setupBackgroundLayout(for container: UIView, backgroundView: RoundedView) {
        container.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.lessThanOrEqualToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }

    func setupContentLayout(for container: UIView, contentView: UIView) {
        container.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(6.0)
            make.top.bottom.equalToSuperview().inset(3.0)
            make.trailing.equalToSuperview().inset(8.0)
        }
    }

    func createBackground() -> RoundedView {
        .create { view in
            view.shadowOpacity = 0.0
            view.fillColor = R.color.colorContainerBorder()!
            view.highlightedFillColor = R.color.colorContainerBorder()!
            view.cornerRadius = 7.0
        }
    }
}

// MARK: - SecurableViewProtocol

extension RoundedIconTitleView: SecurableViewProtocol {
    typealias ViewModel = (title: String, icon: UIImage?)

    func update(with viewModel: ViewModel) {
        bind(title: viewModel.title, icon: viewModel.icon)
    }

    func createSecureOverlay() -> UIView? {
        let container = UIView()

        let dotsOverlay = DotsOverlayView()
        dotsOverlay.configuration = .smallBalance

        let backgroundView = createBackground()

        setupBackgroundLayout(
            for: container,
            backgroundView: backgroundView
        )
        setupContentLayout(
            for: backgroundView,
            contentView: dotsOverlay
        )

        return container
    }
}
