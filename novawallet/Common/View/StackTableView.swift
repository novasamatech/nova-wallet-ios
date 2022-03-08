import UIKit
import SoraUI

final class StackTableView: RoundedView {
    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 8.0, right: 0.0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureStyle() {
        applyFilledBackgroundStyle()

        fillColor = R.color.colorWhite8()!
        cornerRadius = 12.0
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
