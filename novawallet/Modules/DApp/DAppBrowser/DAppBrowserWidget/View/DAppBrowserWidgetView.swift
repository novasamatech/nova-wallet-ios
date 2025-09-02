import UIKit
import UIKit_iOS

class DAppBrowserWidgetView: UIView {
    let backgroundView: BlurBackgroundView = .create { view in
        view.sideLength = Constants.sideLength
        view.cornerCut = [.topLeft, .topRight]
        view.borderWidth = Constants.borderWidth
        view.borderColor = R.color.colorContainerBorder()!
    }

    let contentContainerView = UIView()

    let closeButton: TriangularedButton = .create { view in
        view.applyEnabledStyle(colored: .clear)
        view.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        view.imageWithTitleView?.iconImage = R.image.iconClose()
    }

    let title: IconDetailsView = .create { view in
        view.detailsLabel.apply(style: .semiboldBodyPrimary)
        view.detailsLabel.textAlignment = .center
        view.spacing = 7.0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: DAppBrowserWidgetModel) {
        title.detailsLabel.text = viewModel.title

        if let iconModel = viewModel.icon {
            title.iconWidth = Constants.iconSize.width
            title.spacing = Constants.titleIconSpacing

            iconModel.loadImage(
                on: title.imageView,
                targetSize: Constants.iconSize,
                animated: true
            )
        } else {
            title.spacing = 0
            title.iconWidth = 0
            title.imageView.image = nil
        }
    }
}

// MARK: Private

private extension DAppBrowserWidgetView {
    func setupStyle() {
        backgroundColor = .clear
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(-Constants.borderWidth)
        }

        addSubview(contentContainerView)
        contentContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.leading.equalToSuperview().inset(Constants.closeButtonLeadingInset)
            make.top.equalToSuperview()
        }

        contentContainerView.addSubview(title)
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(Constants.titleHeight)
            make.top.equalToSuperview().inset(Constants.titleTopInset)
        }
    }
}

// MARK: Constants

private extension DAppBrowserWidgetView {
    enum Constants {
        static let sideLength: CGFloat = 16.0
        static let borderWidth: CGFloat = 1.0
        static let closeButtonSize: CGFloat = 41.0
        static let closeButtonLeadingInset: CGFloat = 8.0
        static let titleHeight: CGFloat = 22.0
        static let titleTopInset: CGFloat = 9.0
        static let iconSize = CGSize(width: 20.0, height: 20.0)
        static let titleIconSpacing = 4.0
    }
}
