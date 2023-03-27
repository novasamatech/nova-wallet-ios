import UIKit
import SoraUI

final class ValidatorSearchViewLayout: BaseTableSearchViewLayout {
    override init(frame: CGRect) {
        super.init(frame: frame)

        tableView.estimatedRowHeight = 44
    }
}
