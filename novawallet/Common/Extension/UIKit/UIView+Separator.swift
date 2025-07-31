import UIKit
import SnapKit

extension UIView {
    static func createSeparator(color: UIColor? = R.color.colorDivider()) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        return view
    }

    @discardableResult
    func addBottomSeparator(
        _ height: CGFloat = 1,
        color: UIColor = R.color.colorDivider()!,
        horizontalSpace: CGFloat = 0
    ) -> UIView {
        let separator = UIView.createSeparator(color: color)
        addSubview(separator)

        separator.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(horizontalSpace)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(height)
        }

        return separator
    }
}
