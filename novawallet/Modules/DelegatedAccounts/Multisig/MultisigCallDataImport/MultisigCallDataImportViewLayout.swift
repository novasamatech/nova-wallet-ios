import UIKit
import UIKit_iOS
import SnapKit

final class MultisigCallDataImportViewLayout: SCSingleActionLayoutView {
    let callDataView: MultilineTextInputView = .create { view in
        view.textView.returnKeyType = .default
        view.textView.autocorrectionType = .no
        view.textView.autocapitalizationType = .none
        view.textView.keyboardType = .default
    }

    var actionButton: TriangularedButton {
        genericActionView
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(callDataView, spacingAfter: 16)

        callDataView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(64)
        }
    }

    override func setupStyle() {
        super.setupStyle()

        actionButton.imageWithTitleView?.titleFont = .semiBoldSubheadline
    }
}
