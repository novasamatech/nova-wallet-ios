import UIKit
import SoraUI

final class DelegationReferendumVotersViewLayout: GenericCollectionViewLayout<UILabel> {
    override init(frame _: CGRect) {
        super.init(
            header: .init(),
            settings: GenericCollectionViewLayoutSettings(
                pinToVisibleBounds: false,
                estimatedRowHeight: 44,
                absoluteHeaderHeight: 44,
                sectionContentInsets: .zero
            )
        )

        backgroundColor = R.color.colorBottomSheetBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
