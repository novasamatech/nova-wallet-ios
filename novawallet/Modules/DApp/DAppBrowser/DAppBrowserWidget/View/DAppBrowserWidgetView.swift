import UIKit
import SoraUI

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
        view.imageWithTitleView?.iconImage = R.image.iconClose()
    }

    let title: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.textAlignment = .center
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
}

// MARK: Private

private extension DAppBrowserWidgetView {
    func setupStyle() {
        backgroundColor = .clear
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentContainerView)
        contentContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.leading.equalToSuperview().inset(Constants.closeButtonLeadingInset)
            make.top.equalToSuperview().inset(Constants.closeButtonTopInset)
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
        static let closeButtonSize: CGFloat = 25.0
        static let closeButtonTopInset: CGFloat = 8.0
        static let closeButtonLeadingInset: CGFloat = UIConstants.horizontalInset
        static let titleHeight: CGFloat = 22.0
        static let titleTopInset: CGFloat = 9.0
    }
}
