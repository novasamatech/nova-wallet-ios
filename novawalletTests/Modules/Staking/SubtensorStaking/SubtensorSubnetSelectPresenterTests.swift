import Cuckoo
import Foundation_iOS
import Keystore_iOS
@testable import novawallet
import XCTest

final class SubtensorSubnetSelectPresenterTests: XCTestCase {
    private struct Setup {
        let presenter: SubtensorSubnetSelectPresenter
        let interactor: MockSubnetSelectInteractorInputProtocol
        let wireframe: MockSubtensorSubnetSelectWireframeProtocol
        let delegate: MockSubtensorSubnetSelectDelegate
    }

    func testStakeToRootHandsBackRootWithoutAValidator() {
        let setup = makeSetup()

        stub(setup.wireframe) { stub in
            when(stub.complete(from: any(), target: any(), validator: any(), delegate: any())).thenDoNothing()
        }

        setup.presenter.selectRoot()

        verify(setup.wireframe).complete(
            from: any(),
            target: equal(to: .root),
            validator: isNil(),
            delegate: ParameterMatcher<SubtensorSubnetSelectDelegate?> { $0 === setup.delegate }
        )
    }

    func testCompletingWithoutAPresentedPickerHandsTheTargetAndValidatorToTheDelegate() {
        let wireframe = SubtensorSubnetSelectWireframe(state: MockSubtensorStakingSharedStateProtocol())
        let delegate = MockSubtensorSubnetSelectDelegate()
        let target = makeEntry(netuid: 64, price: 7_683_255).target

        let validator = SubtensorValidatorDirectoryItem(
            hotkey: Data(repeating: 7, count: 32),
            netuid: 64,
            name: "Validator",
            take: nil,
            reportedStake: nil,
            status: nil,
            isNovaPreferred: false
        )

        stub(delegate) { stub in
            when(stub.didSelectStakeTarget(any(), validator: any())).thenDoNothing()
        }

        wireframe.complete(from: nil, target: target, validator: validator, delegate: delegate)

        verify(delegate).didSelectStakeTarget(equal(to: target), validator: equal(to: validator))
    }

    func testSubnetRowOpensItsDetailsWithTheRowChainTarget() {
        let setup = makeSetup()
        let chutes = makeEntry(netuid: 64, price: 7_683_255)
        let apex = makeEntry(netuid: 1, price: 4_120_000)

        stub(setup.interactor) { stub in
            when(stub.loadWeeklyPrices(for: any())).thenDoNothing()
        }

        stub(setup.wireframe) { stub in
            when(stub.showDetails(from: any(), item: any(), delegate: any())).thenDoNothing()
        }

        setup.presenter.didReceive(entries: [apex, chutes])
        setup.presenter.selectSubnet(chutes.subnet.ref)

        verify(setup.wireframe).showDetails(
            from: any(),
            item: ParameterMatcher { $0.target == chutes.target },
            delegate: any()
        )
    }

    func testFailedThirtyDayPricesSwitchTheDraftFilterOffAndShowTheCaption() {
        let setup = makeSetup()
        let filtersView = MockSubtensorSubnetFiltersViewProtocol()

        stub(setup.interactor) { stub in
            when(stub.loadWeeklyPrices(for: any())).thenDoNothing()
            when(stub.loadMonthlyMetrics(for: any())).thenDoNothing()
        }

        stub(setup.wireframe) { stub in
            when(stub.showFilters(from: any(), viewModel: any(), onChange: any(), onApply: any()))
                .thenReturn(filtersView)
        }

        stub(filtersView) { stub in
            when(stub.didReceive(viewModel: any())).thenDoNothing()
        }

        setup.presenter.didReceive(entries: [makeEntry(netuid: 64, price: 7_683_255)])
        setup.presenter.showFilters()
        setup.presenter.draftFilters(SubtensorSubnetFilters(hideThinPools: false, onlyAboveThirtyDayAverage: true))
        setup.presenter.didFailMonthlyMetrics()

        let captor = ArgumentCaptor<SubtensorSubnetFiltersViewModel>()

        verify(setup.interactor).loadMonthlyMetrics(for: any())
        verify(filtersView, times(2)).didReceive(viewModel: captor.capture())

        XCTAssertEqual(captor.value?.filters.onlyAboveThirtyDayAverage, false)
        XCTAssertEqual(captor.value?.unavailableText, "30-day prices are unavailable right now")
        XCTAssertEqual(captor.value?.actionTitle, "Show 1 subnet")
    }

    private func makeSetup() -> Setup {
        let interactor = MockSubnetSelectInteractorInputProtocol()
        let wireframe = MockSubtensorSubnetSelectWireframeProtocol()
        let delegate = MockSubtensorSubnetSelectDelegate()

        let presenter = SubtensorSubnetSelectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SubtensorSubnetViewModelFactory(chainAsset: makeChainAsset()),
            delegate: delegate,
            earnSettings: SubtensorEarnSettings(settingsManager: InMemorySettingsManager()),
            localizationManager: LocalizationManager.shared
        )

        return Setup(presenter: presenter, interactor: interactor, wireframe: wireframe, delegate: delegate)
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
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeEntry(netuid: UInt16, price: Balance) -> SubtensorSubnetListEntry {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        let subnet = SubtensorCatalogueSubnet(
            netuid: netuid,
            name: "Subnet",
            symbol: "α",
            networkRegisteredAt: 4_531_295,
            tempo: 360,
            ownerColdkey: "",
            ownerHotkey: "",
            links: SubtensorSubnetLinks(
                githubRepo: "",
                subnetContact: "",
                subnetUrl: "",
                subnetWebsite: "",
                discord: "",
                additional: ""
            ),
            taoReserve: 210_000_000_000_000,
            alphaReserve: 2_845_000_000_000_000,
            alphaOutstanding: 3_100_000_000_000_000,
            taoPerAlpha: price,
            metadataStamp: stamp,
            pricesStamp: stamp
        )

        let info = SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: UInt8(netuid % 255), count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data(),
            tokenSymbol: Data(),
            tempo: 360,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: 0,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 4_531_295,
            subnetIdentity: nil,
            movingPrice: .null
        )

        return SubtensorSubnetListEntry(subnet: subnet, target: .subnet(info: info, price: price))
    }
}
