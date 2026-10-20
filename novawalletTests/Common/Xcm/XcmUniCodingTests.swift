import XCTest
@testable import novawallet
import SubstrateSdk

final class XcmUniCodingTests: XCTestCase {
    func testEncodeDecodeParachainAccountId32Location() throws {
        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.RelativeLocation(
                        parents: 1,
                        items: [
                            .parachain(2000),
                            .accountId32(
                                XcmUni.AccountId32(
                                    network: .any,
                                    accountId: Data.randomBytes(length: 32)!
                                )
                            )
                        ]
                    ),
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeParachainAccountId20Location() throws {
        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.RelativeLocation(
                        parents: 1,
                        items: [
                            .parachain(2001),
                            .accountKey20(
                                XcmUni.AccountId20(
                                    network: .any,
                                    accountId: Data.randomBytes(length: 20)!
                                )
                            )
                        ]
                    ),
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeRelaychainAccountId32Location() throws {
        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.RelativeLocation(
                        parents: 0,
                        items: [
                            .accountId32(
                                XcmUni.AccountId32(
                                    network: .any,
                                    accountId: Data.randomBytes(length: 32)!
                                )
                            )
                        ]
                    ),
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeRelaychainAccountId20Location() throws {
        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.RelativeLocation(
                        parents: 0,
                        items: [
                            .accountKey20(
                                XcmUni.AccountId20(
                                    network: .any,
                                    accountId: Data.randomBytes(length: 20)!
                                )
                            )
                        ]
                    ),
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeAssetFromAssets() throws {
        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.Asset(
                        location: XcmUni.RelativeLocation(
                            parents: 1,
                            items: [
                                .parachain(1000),
                                .palletInstance(50),
                                .generalIndex(1984)
                            ]
                        ),
                        amount: Decimal(1).toSubstrateAmount(precision: 12)!
                    ),
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeAssetFromOrml() throws {
        let generalKeyData = try! Data(hexString: "0x0080")
        let generalKey = XcmUni.GeneralKeyValue(data: generalKeyData)

        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.Asset(
                        location: XcmUni.RelativeLocation(
                            parents: 1,
                            items: [
                                .parachain(2000),
                                .generalKey(generalKey)
                            ]
                        ),
                        amount: Decimal(1).toSubstrateAmount(precision: 12)!
                    ),
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeMessage() throws {
        let originAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: 2000)
        let destAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: 2002)
        let reserveAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: 1000)
        let amount = Decimal(1).toSubstrateAmount(precision: 6)!
        let destinationAccount: AccountId = Data.randomBytes(length: 32)!

        let assetLocation = XcmUni.AbsoluteLocation(
            items: [
                .parachain(1000),
                .palletInstance(50),
                .generalIndex(1984)
            ]
        )

        let originAsset = try XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation).toAssetId(),
            amount: amount
        )

        let reserveAsset = try XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: reserveAbsoluteLocation).toAssetId(),
            amount: amount
        )

        let destAsset = try XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation).toAssetId(),
            amount: amount
        )

        let beneficiary = try destAbsoluteLocation.appendingAccountId(
            destinationAccount,
            isEthereumBase: false
        ).fromPointOfView(location: destAbsoluteLocation)

        let instructions: [XcmUni.Instruction] = try [
            XcmUni.Instruction.withdrawAsset([originAsset]),
            XcmUni.Instruction.buyExecution(
                XcmUni.BuyExecutionValue(
                    fees: originAsset,
                    weightLimit: .limited(weight: .zero)
                )
            ),
            XcmUni.Instruction.initiateReserveWithdraw(
                XcmUni.InitiateReserveWithdrawValue(
                    assets: .wild(.allCounted(1)),
                    reserve: reserveAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmUni.Instruction.buyExecution(
                            XcmUni.BuyExecutionValue(
                                fees: reserveAsset,
                                weightLimit: .unlimited
                            )
                        ),
                        XcmUni.Instruction.depositReserveAsset(
                            XcmUni.DepositReserveAssetValue(
                                assets: .wild(.allCounted(1)),
                                dest: destAbsoluteLocation.fromPointOfView(location: reserveAbsoluteLocation),
                                xcm: [
                                    XcmUni.Instruction.buyExecution(
                                        XcmUni.BuyExecutionValue(
                                            fees: destAsset,
                                            weightLimit: .unlimited
                                        )
                                    ),
                                    XcmUni.Instruction.depositAsset(
                                        XcmUni.DepositAssetValue(
                                            assets: .wild(.allCounted(1)),
                                            beneficiary: beneficiary
                                        )
                                    )
                                ]
                            )
                        )
                    ]
                )
            )
        ]

        for version in Xcm.Version.allCases {
            try performEncodeDecodeTest(
                for: XcmUni.VersionedMessage(
                    entity: instructions,
                    version: version
                )
            )
        }
    }

    func testEncodeDecodeEthereumConsensusLocation() throws {
        for version in [Xcm.Version.V3, .V4, .V5] {
            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.RelativeLocation(
                        parents: 2,
                        items: [.globalConsensus(.ethereum(chainId: 1))]
                    ),
                    version: version
                )
            )

            try performEncodeDecodeTest(
                for: XcmUni.Versioned(
                    entity: XcmUni.RelativeLocation(
                        parents: 2,
                        items: [
                            .globalConsensus(.ethereum(chainId: 1)),
                            .accountKey20(XcmUni.AccountId20(network: .any, accountId: Data.randomBytes(length: 20)!))
                        ]
                    ),
                    version: version
                )
            )
        }
    }

    func testEthereumConsensusLocationEncodedAsRuntimeExpects() throws {
        let location = XcmUni.RelativeLocation(parents: 2, items: [.globalConsensus(.ethereum(chainId: 1))])
        let encoded = try JSONEncoder().encode(location.versioned(.V4))
        let json = try JSONDecoder().decode(JSON.self, from: encoded)

        let interior = json.arrayValue?[1].dictValue?["interior"]
        XCTAssertEqual(interior?.arrayValue?[0].stringValue, "X1")

        let junction = interior?.arrayValue?[1].arrayValue?[0]
        XCTAssertEqual(junction?.arrayValue?[0].stringValue, "GlobalConsensus")
        XCTAssertEqual(junction?.arrayValue?[1].arrayValue?[0].stringValue, "Ethereum")
        XCTAssertEqual(junction?.arrayValue?[1].arrayValue?[1].dictValue?["chainId"]?.stringValue, "1")
    }

    func testEthereumConsensusLocationRejectsPreV3() {
        let location = XcmUni.RelativeLocation(parents: 2, items: [.globalConsensus(.ethereum(chainId: 1))])

        XCTAssertThrowsError(try JSONEncoder().encode(location.versioned(.V2)))
    }

    private func performEncodeDecodeTest<T: Equatable & XcmUniCodable>(
        for versionedEntity: XcmUni.Versioned<T>
    ) throws {
        let encoded = try JSONEncoder().encode(versionedEntity)
        let decoded = try JSONDecoder().decode(XcmUni.Versioned<T>.self, from: encoded)

        XCTAssertEqual(versionedEntity, decoded)
    }
}
