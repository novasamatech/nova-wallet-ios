import UIKit

extension UIView {
    func insertSwapBackground() {
        let backgroundView = MultigradientView.background

        insertSubview(backgroundView, at: 0)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
