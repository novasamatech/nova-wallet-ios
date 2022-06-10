import Foundation
import UIKit

final class LoadableActionView: UIView {
    let actionLoadingView: ActionLoadingView = {
        let view = ActionLoadingView()
        view.isHidden = true
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(actionLoadingView)
        actionLoadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func startLoading() {
        actionButton.isHidden = true
        actionLoadingView.isHidden = false
        actionLoadingView.start()
    }

    func stopLoading() {
        actionLoadingView.stop()
        actionButton.isHidden = false
        actionLoadingView.isHidden = true
    }
}
