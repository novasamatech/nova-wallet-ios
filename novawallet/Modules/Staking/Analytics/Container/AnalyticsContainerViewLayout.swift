import UIKit
import SoraUI

final class AnalyticsContainerViewLayout: UIView {
    let segmentedControl: PlainSegmentedControl = {
        let segmentedControl = PlainSegmentedControl()
        segmentedControl.selectionWidth = 1
        segmentedControl.titleColor = R.color.colorTextSecondary()!
        segmentedControl.selectionColor = R.color.colorIconPrimary()!
        segmentedControl.selectedTitleColor = R.color.colorIconPrimary()!
        segmentedControl.titleFont = .p1Paragraph
        return segmentedControl
    }()

    let horizontalScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
        return scrollView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        addSubview(horizontalScrollView)
        horizontalScrollView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
