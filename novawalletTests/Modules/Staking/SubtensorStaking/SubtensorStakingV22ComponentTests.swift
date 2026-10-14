@testable import novawallet
import UIKit
import XCTest

final class SubtensorStakingV22ComponentTests: XCTestCase {
    func testPickRowsUseSingleTopDividersAndClearHiddenRows() {
        let view = SubtensorPickCardView()
        func model(receive: SubtensorSetupRowViewModel) -> SubtensorPickCardViewModel {
            .init(
                validator: .unselected(title: "Select"),
                validatorRate: nil,
                isValidatorEditable: true,
                browseTitle: nil,
                header: nil,
                chips: [],
                receive: receive,
                swapRate: .value("Rate"),
                networkFee: nil
            )
        }
        view.bind(viewModel: model(receive: .value("1 α")))
        XCTAssertEqual(view.validatorCell.borderView.borderType, [])
        for cell in [view.receiveCell, view.swapRateCell, view.networkFeeCell] {
            XCTAssertEqual(cell.borderView.borderType, .top)
            XCTAssertEqual(cell.borderView.strokeWidth, 0.5)
            XCTAssertEqual(cell.borderView.strokeColor, R.color.colorDivider())
        }
        view.bind(viewModel: model(receive: .hidden))
        XCTAssertTrue(view.receiveCell.isHidden)
        XCTAssertEqual(view.swapRateCell.borderView.borderType, .top)
        XCTAssertEqual(view.rowsView.contentInsets, .zero)
    }

    func testMoreDetailsRetainsExpansionAcrossDataAndTitleRefresh() {
        let view = SubtensorSubnetMoreDetailsView()
        view.bind([.init(title: "UID", value: "1", detail: nil)])
        XCTAssertFalse(view.expanded)
        view.titleControl.sendActions(for: .valueChanged)
        XCTAssertTrue(view.expanded)
        view.titleControl.titleLabel.text = "Details"
        view.bind([.init(title: "UID", value: "2", detail: nil), .init(title: "Alpha", value: "3", detail: "$4")])
        XCTAssertTrue(view.expanded)
        XCTAssertFalse(view.stackView.arrangedSubviews[1].isHidden)
        view.titleControl.sendActions(for: .valueChanged)
        XCTAssertFalse(view.expanded)
    }

    func testValidatorIdentityReplacementCancelsAndFixedCompactRowHidesChevron() {
        let first = ImageSpy()
        let second = ImageSpy()
        let view = SubtensorValidatorCardView()
        view.bind(viewModel: .init(icon: first, name: "A", subtitle: "Validator", rate: .loading, rateCaption: "Est. APY"))
        view.bind(viewModel: .init(icon: second, name: "B", subtitle: "Validator", rate: .hidden, rateCaption: "Est. APY"))
        XCTAssertEqual(first.loads, 1)
        XCTAssertEqual(first.cancels, 1)
        XCTAssertEqual(second.loads, 1)
        XCTAssertEqual(view.nameLabel.text, "B")
        let compact = SubtensorPickValidatorCell()
        compact.bind(validator: .selected(.init(address: "address", name: "B", imageViewModel: second), accessory: .info), rate: "Est. 7% APY", isEditable: false)
        XCTAssertFalse(compact.canSelect)
        XCTAssertNil(compact.accessoryImageView.image)
        XCTAssertEqual(compact.detailsLabel.text, "B\nEst. 7% APY")
    }

    func testNoTaoCaptionFollowsActionAndConfirmationNotesFollowWallet() {
        let setup = SubtensorStakingSetupViewLayout()
        setup.placeCaption(afterAction: true)
        let stack = setup.actionButton.superview as! UIStackView
        XCTAssertTrue(stack.arrangedSubviews[0] === setup.actionButton)
        XCTAssertTrue(stack.arrangedSubviews[1] === setup.captionLabel)
        setup.placeCaption(afterAction: false)
        XCTAssertTrue(stack.arrangedSubviews[0] === setup.captionLabel)
        let confirm = SubtensorStakingConfirmViewLayout()
        confirm.setupMode(.swap(.buy))
        let notes = confirm.feeDisclosureLabel.superview as! UIStackView
        XCTAssertGreaterThan(notes.arrangedSubviews.firstIndex(of: confirm.feeDisclosureLabel)!, notes.arrangedSubviews.firstIndex(of: confirm.remarkLabel)!)
        XCTAssertEqual(confirm.feeDisclosureLabel.textAlignment, .center)
    }
}

private final class ImageSpy: ImageViewModelProtocol {
    var loads = 0
    var cancels = 0
    func loadImage(on _: UIImageView, settings _: ImageViewModelSettings, animated _: Bool) { loads += 1 }
    func cancel(on _: UIImageView) { cancels += 1 }
}
