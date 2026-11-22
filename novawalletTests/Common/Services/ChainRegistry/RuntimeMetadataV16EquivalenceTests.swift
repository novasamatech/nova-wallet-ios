@testable import novawallet
import SubstrateSdk
import XCTest

/// Metadata v16 of a runtime has to describe everything the app reads from v15 the same way: pallets,
/// calls, events, storage, constants, the base transaction extensions and runtime apis. Checked on the real
/// metadata of `RuntimeMetadataFixture`, v15 and v16 of one spec version.
final class RuntimeMetadataV16EquivalenceTests: XCTestCase {
    func testV16DescribesTheRuntimeAsV15Does() throws {
        for fixture in RuntimeMetadataFixture.all {
            let outlines = try RuntimeMetadataOutline.make(for: [
                fixture.postV14Metadata(version: 15),
                fixture.postV14Metadata(version: 16)
            ])

            XCTAssertEqual(RuntimeMetadataOutline.differences(outlines[0], outlines[1]), [], fixture.name)

            // the outline is not empty by accident
            XCTAssertGreaterThan(outlines[0].count, 500, fixture.name)
            XCTAssertNotNil(outlines[0]["pallet/System/storage/Account"])
            XCTAssertNotNil(outlines[0]["pallet/Balances/calls"])
            XCTAssertNotNil(outlines[0]["pallet/Balances/constant/ExistentialDeposit"])
            XCTAssertNotNil(outlines[0]["api/TransactionPaymentApi/query_info"])
            XCTAssertNotNil(outlines[0]["extension/0"])
            XCTAssertEqual(outlines[0]["extrinsic"]?.split(separator: " ").count, 3)
        }
    }

    func testOutlineTellsDifferentRuntimesApart() throws {
        let assetHub = try RuntimeMetadataFixture.polkadotAssetHub.postV14Metadata(version: 16)
        let polkadot = try RuntimeMetadataFixture.polkadot.postV14Metadata(version: 16)

        let outlines = try RuntimeMetadataOutline.make(for: [assetHub, polkadot])
        let differences = RuntimeMetadataOutline.differences(outlines[0], outlines[1])

        // different pallets, and the same extension typed differently: Asset Hub pays fees in assets
        XCTAssertTrue(differences.contains("pallet/Assets/calls"))
        XCTAssertTrue(differences.contains("extension/8"))

        // the types both runtimes share get the same label though their ids differ
        XCTAssertEqual(outlines[0]["pallet/System/storage/Account"], outlines[1]["pallet/System/storage/Account"])
        XCTAssertEqual(outlines[0]["extension/6"], outlines[1]["extension/6"])
    }

    func testV16ListsFormatsAndExtensionVersions() throws {
        let assetHub = try RuntimeMetadataFixture.polkadotAssetHub.runtime(version: 16).metadata
        let polkadot = try RuntimeMetadataFixture.polkadot.runtime(version: 16).metadata

        XCTAssertEqual(assetHub.getSupportedFormatVersions(), [4, 5])
        XCTAssertEqual(polkadot.getSupportedFormatVersions(), [4, 5])

        XCTAssertEqual(polkadot.getSupportedExtensionVersions(), [0])
        XCTAssertFalse(polkadot.getSignedExtensions().contains(Extrinsic.TransactionExtensionId.verifySignature))

        // Asset Hub already has a second extension set, the one general transactions are signed with
        XCTAssertEqual(assetHub.getSupportedExtensionVersions(), [0, 1])
        XCTAssertFalse(
            try assetHub.getSignedExtensions(forExtensionVersion: 0)
                .contains(Extrinsic.TransactionExtensionId.verifySignature)
        )
        XCTAssertTrue(
            try assetHub.getSignedExtensions(forExtensionVersion: 1)
                .contains(Extrinsic.TransactionExtensionId.verifySignature)
        )
    }

    func testBaseExtensionSetOfV16IsTheSetOfV15() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15 = try fixture.runtime(version: 15).metadata
            let v16 = try fixture.runtime(version: 16).metadata

            XCTAssertNil(v15.getSupportedFormatVersions())
            XCTAssertEqual(v15.getSupportedExtensionVersions(), [0])

            XCTAssertEqual(
                try v16.getSignedExtensions(forExtensionVersion: Extrinsic.Version.baseExtensionVersion),
                v15.getSignedExtensions(),
                fixture.name
            )
        }
    }

    func testIdentifiersOfV16ExtensionsAreUnique() throws {
        // the app's coders look an extension type up by the identifier alone
        for fixture in RuntimeMetadataFixture.all {
            let identifiers = try fixture.runtime(version: 16).metadata.getSignedExtensions()

            XCTAssertEqual(Set(identifiers).count, identifiers.count, fixture.name)
        }
    }

    func testMetadataHashSupportDoesNotDependOnMetadataVersion() throws {
        for fixture in RuntimeMetadataFixture.all {
            XCTAssertTrue(try fixture.runtime(version: 15).codingFactory.supportsMetadataHash())
            XCTAssertTrue(try fixture.runtime(version: 16).codingFactory.supportsMetadataHash())
            XCTAssertTrue(try fixture.runtime(version: 16).codingFactory.atLeastV15Runtime())
        }

        // metadata v14 can't be merkleized, whatever extensions it lists
        let v14Runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        XCTAssertTrue(
            v14Runtime.metadata.getSignedExtensions().contains(Extrinsic.TransactionExtensionId.checkMetadataHash)
        )
        XCTAssertFalse(v14Runtime.codingFactory.supportsMetadataHash())
    }

    func testCallsAndEventsAreFoundTheSameWay() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15 = try fixture.runtime(version: 15).metadata
            let v16 = try fixture.runtime(version: 16).metadata

            var callsCount = 0
            var eventsCount = 0

            for moduleIndex in UInt8.min ... UInt8.max {
                XCTAssertEqual(v16.getModuleName(by: moduleIndex), v15.getModuleName(by: moduleIndex))

                for itemIndex in UInt8.min ... UInt8.max {
                    let v15Call = v15.getCallByModuleIndex(moduleIndex, callIndex: itemIndex)
                    let v16Call = v16.getCallByModuleIndex(moduleIndex, callIndex: itemIndex)

                    XCTAssertEqual(v16Call?.name, v15Call?.name)
                    XCTAssertEqual(v16Call?.arguments.map(\.name), v15Call?.arguments.map(\.name))

                    let v15Event = v15.getEventForModuleIndex(moduleIndex, eventIndex: UInt32(itemIndex))
                    let v16Event = v16.getEventForModuleIndex(moduleIndex, eventIndex: UInt32(itemIndex))

                    XCTAssertEqual(v16Event?.name, v15Event?.name)
                    XCTAssertEqual(v16Event?.arguments.count, v15Event?.arguments.count)

                    callsCount += v15Call != nil ? 1 : 0
                    eventsCount += v15Event != nil ? 1 : 0
                }
            }

            XCTAssertGreaterThan(callsCount, 100, fixture.name)
            XCTAssertGreaterThan(eventsCount, 100, fixture.name)
        }
    }

    func testRuntimeApisAreFoundTheSameWay() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v16 = try fixture.runtime(version: 16).metadata

            guard let v15 = try fixture.runtime(version: 15).metadata as? RuntimeMetadataV15 else {
                return XCTFail("Metadata v15 expected")
            }

            var methodsCount = 0

            for api in v15.apis {
                for method in api.methods {
                    let v15Method = v15.getRuntimeApiMethod(for: api.name, methodName: method.name)
                    let v16Method = v16.getRuntimeApiMethod(for: api.name, methodName: method.name)

                    XCTAssertNotNil(v16Method, "\(api.name).\(method.name)")
                    XCTAssertEqual(v16Method?.callName, v15Method?.callName)
                    XCTAssertEqual(v16Method?.method.inputs.map(\.name), v15Method?.method.inputs.map(\.name))

                    methodsCount += 1
                }
            }

            XCTAssertGreaterThan(methodsCount, 50, fixture.name)

            // the apis the fee and nonce of every transaction come from
            XCTAssertEqual(
                v16.getRuntimeApiMethod(for: "TransactionPaymentApi", methodName: "query_info")?.callName,
                "TransactionPaymentApi_query_info"
            )
            XCTAssertNotNil(v16.getRuntimeApiMethod(for: "AccountNonceApi", methodName: "account_nonce"))
            XCTAssertNil(v16.getRuntimeApiMethod(for: "TransactionPaymentApi", methodName: "unknown"))
        }
    }
}
