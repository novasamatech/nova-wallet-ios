import UIKit

final class BrowserWidgetViewLayout: UIView {
    let browserVidgetView = DAppBrowserWidgetView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(browserVidgetView)
        browserVidgetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
