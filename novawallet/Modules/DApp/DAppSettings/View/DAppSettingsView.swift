import UIKit
import SnapKit

final class DAppSettingsView: UIView {
    let iconDetailsView = IconDetailsView()
    let switchView: UISwitch = .create {
        $0.onTintColor = R.color.colorIconAccent()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let contentView = UIView.hStack([
            iconDetailsView,
            switchView
        ])
        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
