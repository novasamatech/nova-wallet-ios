import UIKit

final class DAppBrowserWidgetViewLayout: UIView {
    let browserWidgetView = DAppBrowserWidgetView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(browserWidgetView)
        browserWidgetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
