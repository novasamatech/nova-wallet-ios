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

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupPage(view: UIView) {
        insertSubview(view, belowSubview: segmentedControl)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

private extension PayRootViewLayout {
    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.segmentedControlVerticalInset)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(UIConstants.segmentedControlHeight)
        }
    }
}
