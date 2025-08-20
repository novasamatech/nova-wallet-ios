import UIKit

final class MultisigOperationViewLayout: UIView {
    let loadingView = ListLoadingView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(loadingView)

        loadingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
