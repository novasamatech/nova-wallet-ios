import XCTest
import Cuckoo
import BigInt
import Foundation_iOS
@testable import novawallet

final class SubtensorSlippagePresenterTests: XCTestCase {
    private struct Setup {
        let presenter: SwapSlippagePresenter
        let view: MockSwapSlippageViewProtocol
        let wireframe: MockSwapSlippageWireframeProtocol
    }

    private func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            enabled: true,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeSetup(
        initSlippage: BigRational? = BigRational(numerator: 5, denominator: 1000),
        onApply: @escaping (BigRational) -> Void = { _ in }
    ) -> Setup {
        let view = MockSwapSlippageViewProtocol()

        stub(view) { stub in
            when(stub.didReceivePreFilledPercents(viewModel: any())).thenDoNothing()
            when(stub.didReceiveInput(viewModel: any())).thenDoNothing()
            when(stub.didReceiveInput(error: any())).thenDoNothing()
            when(stub.didReceiveInput(warning: any())).thenDoNothing()
            when(stub.didReceiveResetState(available: any())).thenDoNothing()
            when(stub.didReceiveButtonState(available: any())).thenDoNothing()
        }

        let wireframe = MockSwapSlippageWireframeProtocol()

        stub(wireframe) { stub in
            when(stub.close(from: any())).thenDoNothing()
        }

        let presenter = SwapSlippagePresenter(
            wireframe: wireframe,
            percentFormatterLocalizable: NumberFormatter.percentSingle.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initSlippage: initSlippage,
            config: SlippageConfig.subtensorStaking,
            chainAsset: makeChainAsset(),
            completionHandler: onApply
        )

        presenter.view = view
        presenter.setup()

        return Setup(presenter: presenter, view: view, wireframe: wireframe)
    }

    private func lastError(of view: MockSwapSlippageViewProtocol) -> String? {
        let captor = ArgumentCaptor<String?>()
        verify(view, atLeastOnce()).didReceiveInput(error: captor.capture())
        return captor.value ?? nil
    }

    private func lastWarning(of view: MockSwapSlippageViewProtocol) -> String? {
        let captor = ArgumentCaptor<String?>()
        verify(view, atLeastOnce()).didReceiveInput(warning: captor.capture())
        return captor.value ?? nil
    }

    private func lastApplyAvailable(of view: MockSwapSlippageViewProtocol) -> Bool? {
        let captor = ArgumentCaptor<Bool>()
        verify(view, atLeastOnce()).didReceiveButtonState(available: captor.capture())
        return captor.value
    }

    private func lastInputPercent(of view: MockSwapSlippageViewProtocol) -> Decimal? {
        let captor = ArgumentCaptor<AmountInputViewModelProtocol>()
        verify(view, atLeastOnce()).didReceiveInput(viewModel: captor.capture())
        return captor.value?.decimalAmount
    }

    func testSetupProvidesSubtensorPresetTips() {
        let setup = makeSetup()

        let captor = ArgumentCaptor<[SlippagePercentViewModel]>()
        verify(setup.view, atLeastOnce()).didReceivePreFilledPercents(viewModel: captor.capture())

        XCTAssertEqual(
            captor.value?.map(\.value),
            ["0.001", "0.005", "0.01", "0.03"].compactMap { Decimal(string: $0) }
        )
    }

    func testSetupPrefillsInitialSlippageAsPercent() {
        let setup = makeSetup(initSlippage: BigRational(numerator: 3, denominator: 100))

        XCTAssertEqual(lastInputPercent(of: setup.view), Decimal(string: "3"))
    }

    func testThreePercentPresetProducesNoWarningOrError() {
        let setup = makeSetup()

        setup.presenter.select(percent: SlippagePercentViewModel(value: Decimal(3) / Decimal(100), title: "3%"))

        XCTAssertNil(lastWarning(of: setup.view))
        XCTAssertNil(lastError(of: setup.view))
    }

    func testApplyAfterPresetSelectionDeliversFractionAndCloses() {
        var applied: BigRational?
        let setup = makeSetup(onApply: { applied = $0 })

        setup.presenter.select(percent: SlippagePercentViewModel(value: Decimal(1) / Decimal(100), title: "1%"))
        setup.presenter.apply()

        XCTAssertEqual(applied?.decimalValue, Decimal(string: "0.01"))
        verify(setup.wireframe).close(from: any())
    }

    func testCustomInputBelowMinimumBoundDisablesApply() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "0.005"))

        XCTAssertNotNil(lastError(of: setup.view))
        XCTAssertEqual(lastApplyAvailable(of: setup.view), false)
    }

    func testCustomInputAboveMaximumBoundDisablesApply() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "51"))

        XCTAssertNotNil(lastError(of: setup.view))
        XCTAssertEqual(lastApplyAvailable(of: setup.view), false)
    }

    func testMinimumBoundInputIsAcceptedWithLowWarning() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "0.01"))

        XCTAssertNil(lastError(of: setup.view))
        XCTAssertNotNil(lastWarning(of: setup.view))
        XCTAssertEqual(lastApplyAvailable(of: setup.view), true)
    }

    func testCustomInputAboveBigSlippageWarnsButKeepsApplyEnabled() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "5"))

        XCTAssertNil(lastError(of: setup.view))
        XCTAssertNotNil(lastWarning(of: setup.view))
        XCTAssertEqual(lastApplyAvailable(of: setup.view), true)
    }

    func testCustomInputWithinRecommendedRangeIsClean() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "1"))

        XCTAssertNil(lastError(of: setup.view))
        XCTAssertNil(lastWarning(of: setup.view))
        XCTAssertEqual(lastApplyAvailable(of: setup.view), true)
    }

    func testApplyWithCustomInputDeliversFraction() {
        var applied: BigRational?
        let setup = makeSetup(onApply: { applied = $0 })

        setup.presenter.updateAmount(Decimal(string: "1.5"))
        setup.presenter.apply()

        XCTAssertEqual(applied?.decimalValue, Decimal(string: "0.015"))
    }

    func testUnchangedInputKeepsApplyDisabled() {
        let setup = makeSetup()

        setup.presenter.updateAmount(Decimal(string: "0.5"))

        XCTAssertEqual(lastApplyAvailable(of: setup.view), false)
    }

    func testResetRestoresDefaultSlippage() {
        let setup = makeSetup(initSlippage: BigRational(numerator: 3, denominator: 100))

        setup.presenter.reset()

        XCTAssertEqual(lastInputPercent(of: setup.view), Decimal(string: "0.5"))
        XCTAssertEqual(lastApplyAvailable(of: setup.view), true)
    }

    func testSubtensorFactoryCreatesView() {
        let view = SwapSlippageViewFactory.createSubtensorView(
            percent: BigRational(numerator: 5, denominator: 1000),
            chainAsset: makeChainAsset()
        ) { _ in }

        XCTAssertNotNil(view)
    }
}
