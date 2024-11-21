import UIKit

final class SwapExecutionViewLayout: ScrollableContainerLayoutView {
    let statusTitleView: MultiValueView = .create { view in
        view.apply(
            style: .init(
                topLabel: .boldTitle1Primary,
                bottomLabel: .semiboldBodyButtonAccent
            )
        )
        
        view.valueTop.textAlignment = .center
        view.valueBottom.textAlignment = .center
        
        view.spacing = 4
    }
    
    let pairsView = SwapPairView()
    
    let details = SwapExecutionDetailsView()

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }
    
    override func setupLayout() {
        super.setupLayout()
        
        stackView.layoutMargins = UIEdgeInsets(top: 76, left: 16, bottom: 0, right: 16)

        addArrangedSubview(statusTitleView, spacingAfter: 24)
        addArrangedSubview(pairsView, spacingAfter: 8)
        addArrangedSubview(details, spacingAfter: 24)
    }
}
