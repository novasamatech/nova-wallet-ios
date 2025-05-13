import UIKit

final class PayRootViewLayout: UIView {
    private let backgroundView = MultigradientView.background
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PayRootViewLayout {
    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
