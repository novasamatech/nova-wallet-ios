import UIKit
import SoraUI

class DAppBrowserWidgetView: UIView {
    let backgroundView: OverlayBlurBackgroundView = .create { view in
        view.sideLength = 16
        view.cornerCut = [.topLeft, .topRight]
        view.borderType = .none
        view.overlayView.fillColor = .clear
        view.overlayView.strokeColor = R.color.colorCardActionsBorder()!
        view.overlayView.strokeWidth = 1
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
            make.size.equalTo(25)
            make.leading.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(8.0)
        }

        contentContainerView.addSubview(title)
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(22)
            make.top.equalToSuperview().inset(9)
        }
    }
}
