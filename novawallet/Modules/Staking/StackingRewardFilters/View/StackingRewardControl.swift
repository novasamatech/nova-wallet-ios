import UIKit
import SoraUI

class StackingRewardControl<TControl: UIControl>: UITableViewHeaderFooterView {
    let titleLabel = UILabel(style: .footnoteSecondary)
    lazy var control = createControl()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func createControl() -> TControl {
        TControl()
    }

    private func setupLayout() {
        let contentView = UIView.hStack(spacing: 4, [
            titleLabel,
            FlexibleSpaceView(),
            control
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
