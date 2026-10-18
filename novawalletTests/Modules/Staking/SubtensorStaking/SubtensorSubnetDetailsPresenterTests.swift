import Cuckoo
import Foundation_iOS
import Keystore_iOS
@testable import novawallet
import XCTest

final class SubtensorSubnetDetailsPresenterTests: XCTestCase {
    private struct Setup {
        let presenter: SubtensorSubnetDetailsPresenter
        let interactor: MockSubnetDetailsInteractorInputProtocol
        let wireframe: MockSubtensorSubnetDetailsWireframeProtocol
        let target: SubtensorStakeTarget
    }

    func testPickerPresetAsksForTheExistingPositionValidatorFirst() {
        let setup = makeSetup()
        let primaryHotkey = Data(repeating: 7, count: 32)
        let secondaryHotkey = Data(repeating: 8, count: 32)
        let otherSubnetHotkey = Data(repeating: 9, count: 32)

        stub(setup.interactor) { stub in
            when(stub.presetValidator(existingHotkey: any())).thenDoNothing()
        }

        let positions = Multistaking.SubtensorStakingState(
            positions: [
                makePosition(hotkey: otherSubnetHotkey, netuid: 1, stakeAlpha: 90_000_000_000),
                makePosition(hotkey: secondaryHotkey, netuid: 64, stakeAlpha: 3_000_000_000),
                makePosition(hotkey: primaryHotkey, netuid: 64, stakeAlpha: 12_000_000_000)
            ],
            prices: [1: 4_120_000, 64: 73_800_000]
        )

        setup.presenter.didReceivePositions(positions)

        verify(setup.interactor).presetValidator(existingHotkey: equal(to: primaryHotkey))
    }

    func testUseSubnetWithoutAValidatorCompletesWithTheValidatorPickedOnTheList() {
        let setup = makeSetup()
        let validator = makeValidator()

        stub(setup.interactor) { stub in
            when(stub.presetValidator(existingHotkey: any())).thenDoNothing()
        }

        stub(setup.wireframe) { stub in
            when(stub.showValidators(from: any(), target: any(), selectedHotkey: any(), delegate: any()))
                .thenDoNothing()
            when(stub.complete(from: any(), host: any(), target: any(), validator: any(), delegate: any()))
                .thenDoNothing()
        }

        setup.presenter.didReceivePositionsSyncFailed(true)
        setup.presenter.didReceivePreset(nil)
        setup.presenter.useSubnet()
        setup.presenter.didSelectValidator(validator, for: setup.target)

        verify(setup.interactor).presetValidator(existingHotkey: isNil())
        verify(setup.wireframe).showValidators(
            from: any(),
            target: equal(to: setup.target),
            selectedHotkey: isNil(),
            delegate: any()
        )
        verify(setup.wireframe).complete(
            from: any(),
            host: equal(to: .picker),
            target: equal(to: setup.target),
            validator: equal(to: validator),
            delegate: any()
        )
    }

    private func makeSetup() -> Setup {
        let interactor = MockSubnetDetailsInteractorInputProtocol()
        let wireframe = MockSubtensorSubnetDetailsWireframeProtocol()
        let subnet = makeSubnet()
        let target = makeTarget(for: subnet)

        let presenter = SubtensorSubnetDetailsPresenter(
            input: SubtensorSubnetDetailsInput(subnet: subnet, target: target, validator: nil),
            host: .picker,
            selectionDelegate: MockSubtensorSubnetSelectDelegate(),
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SubtensorSubnetDetailsViewModelFactory(
                subnet: subnet,
                chainAsset: makeChainAsset(),
                currency: .usd,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
            ),
            earnSettings: SubtensorEarnSettings(settingsManager: InMemorySettingsManager()),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        return Setup(presenter: presenter, interactor: interactor, wireframe: wireframe, target: target)
    }

    private func makePosition(hotkey: AccountId, netuid: UInt16, stakeAlpha: Balance) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stakeAlpha,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: true
        )
    }

    private func makeValidator() -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: Data(repeating: 5, count: 32),
            netuid: 64,
            name: "Nova Wallet",
            take: nil,
            reportedStake: nil,
            status: nil
        )
    }

    private func makeSubnet() -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
            netuid: 64,
            name: "Chutes",
            symbol: "ش",
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
            taoPerAlpha: 73_800_000,
            metadataStamp: stamp,
            pricesStamp: stamp
        )
    }

    private func makeTarget(for subnet: SubtensorCatalogueSubnet) -> SubtensorStakeTarget {
        let info = SubtensorStakingPallet.DynamicInfo(
            netuid: subnet.netuid,
            ownerHotkey: Data(repeating: 1, count: 32),
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
            networkRegisteredAt: subnet.networkRegisteredAt,
            subnetIdentity: nil,
            movingPrice: .null
        )

        return .subnet(info: info, price: subnet.taoPerAlpha)
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
}
