import UIKit
import UIKit_iOS

final class PayRootViewLayout: UIView {
    enum Constants {
        static let segmentedControlVerticalInset: CGFloat = 8
    }

    private let backgroundView = MultigradientView.background

    let segmentedControl: RoundedSegmentedControl = .create { view in
        view.applyPageSwitchStyle()
    }

    var segmentedControlAreaHeight: CGFloat {
        2 * Constants.segmentedControlVerticalInset + UIConstants.segmentedControlHeight
    }

    private var barExtendingView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupPage(view: UIView) {
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func provideTopBarExtensionDecoration() -> UIView {
        if let barExtendingView {
            return barExtendingView
        }

        let view = UIView()

        view.addSubview(segmentedControl)

        segmentedControl.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Constants.segmentedControlVerticalInset)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(UIConstants.segmentedControlHeight)
        }

        barExtendingView = view

        return view
    }
}

private extension PayRootViewLayout {
    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
