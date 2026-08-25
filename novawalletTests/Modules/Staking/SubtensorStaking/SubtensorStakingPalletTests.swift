import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorStakingPalletTests: XCTestCase {
    func testStorageItemsExistInFinneyMetadata() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let storagePaths: [StorageCodingPath] = [
            SubtensorStakingPallet.stakingHotkeysPath,
            SubtensorStakingPallet.totalHotkeyAlphaPath,
            SubtensorStakingPallet.ownerPath,
            SubtensorStakingPallet.subtokenEnabledPath,
            SubtensorStakingPallet.tokenSymbolPath,
            SubtensorStakingPallet.coldkeySwapAnnouncementsPath,
            SubtensorStakingPallet.taoWeightPath,
            SubtensorStakingPallet.rootStakeUnlockIntervalPath,
            SubtensorStakingPallet.lastColdkeyHotkeyStakeBlockPath,
            SubtensorStakingPallet.feeRatePath
        ]

        for storagePath in storagePaths {
            XCTAssertTrue(
                codingFactory.hasStorage(for: storagePath),
                "Missing storage \(storagePath.moduleName).\(storagePath.itemName)"
            )
        }
    }

    func testInitialMinStakeConstantDecodes() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let constant = try XCTUnwrap(
            codingFactory.getConstant(for: SubtensorStakingPallet.initialMinStakePath)
        )

        let decoder = try codingFactory.createDecoder(from: constant.value)
        let minStake: StringScaleMapper<Balance> = try decoder.read(of: constant.type)

        XCTAssertEqual(minStake.value, BigUInt(2_000_000))
    }

    func testRuntimeApisResolveInFinneyMetadata() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let apiPaths: [StateCallPath] = [
            SubtensorStakingPallet.stakeInfoForColdkeyApi,
            SubtensorStakingPallet.stakeAvailabilityForColdkeysApi,
            SubtensorStakingPallet.allDynamicInfoApi,
            SubtensorStakingPallet.delegatesApi,
            SubtensorStakingPallet.alphaPriceAllApi,
            SubtensorStakingPallet.simSwapTaoForAlphaApi,
            SubtensorStakingPallet.simSwapAlphaForTaoApi
        ]

        for apiPath in apiPaths {
            XCTAssertNotNil(
                codingFactory.metadata.getRuntimeApiMethod(for: apiPath.module, methodName: apiPath.method),
                "Missing runtime api \(apiPath.module).\(apiPath.method)"
            )
        }
    }
}
