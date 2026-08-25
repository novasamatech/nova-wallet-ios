import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class SignedExtensionConformanceTests: XCTestCase {
    func testBittensorFinney() {
        do {
            let runtime = try Self.finneyRuntime.get()

            let report = try performConformanceCheck(for: runtime)

            report.classifications.forEach { Logger.shared.info($0) }

            XCTAssertTrue(
                report.violations.isEmpty,
                "Extrinsic builder cannot faithfully encode: \(report.violations.joined(separator: "; "))"
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBittensorFinneyMetadataCanary() {
        do {
            let runtime = try Self.finneyRuntime.get()

            let identifiers = runtime.metadata.postV14Extrinsic.signedExtensions.map(\.identifier)

            XCTAssertEqual(identifiers.count, Self.pinnedTransactionExtensionSlots.count, "\(identifiers)")

            for (identifier, slot) in zip(identifiers, Self.pinnedTransactionExtensionSlots) {
                XCTAssertTrue(slot.contains(identifier), "Unexpected extension \(identifier) in place of \(slot)")
            }

            let constant = try XCTUnwrap(
                runtime.codingFactory.getConstant(for: SubtensorStakingPallet.initialMinStakePath)
            )

            let decoder = try runtime.codingFactory.createDecoder(from: constant.value)
            let minStake: StringScaleMapper<UInt64> = try decoder.read(of: constant.type)

            XCTAssertGreaterThan(minStake.value, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performConformanceCheck(
        for runtime: RuntimeContext
    ) throws -> SignedExtensionConformanceReport {
        let registeredIdentifiers = try deriveRegisteredExtensionIdentifiers(
            for: runtime.chainId,
            genesisHash: runtime.genesisHash
        )

        return classifySignedExtensions(
            in: runtime.metadata,
            registeredIdentifiers: registeredIdentifiers,
            encoder: runtime.codingFactory.createEncoder()
        )
    }

    private func deriveRegisteredExtensionIdentifiers(
        for chainId: ChainModel.Id,
        genesisHash: String
    ) throws -> Set<String> {
        let builder = ExtrinsicBuilder(
            specVersion: 0,
            transactionVersion: 0,
            genesisHash: genesisHash
        )

        let builderExtensions = Mirror(reflecting: builder).children.first {
            $0.label == "transactionExtensions"
        }?.value as? [String: TransactionExtending]

        guard let builderExtensions, !builderExtensions.isEmpty else {
            throw SignedExtensionConformanceError.builderExtensionsUnavailable
        }

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chainId)

        let appExtensionIds = signedExtensionFactory.createExtensions().map(\.txExtensionId)

        return Set(builderExtensions.keys).union(appExtensionIds)
    }

    private func classifySignedExtensions(
        in metadata: PostV14RuntimeMetadataProtocol,
        registeredIdentifiers: Set<String>,
        encoder: DynamicScaleEncoding
    ) -> SignedExtensionConformanceReport {
        var classifications: [String] = []
        var violations: [String] = []

        for signedExtension in metadata.postV14Extrinsic.signedExtensions {
            let identifier = signedExtension.identifier

            if registeredIdentifiers.contains(identifier) {
                classifications.append("\(identifier): registered")
                continue
            }

            let extraIsUnit = isUnitType(signedExtension.type, in: metadata.types)
            let additionalSignedIsUnit = isUnitType(signedExtension.additionalSigned, in: metadata.types)

            if extraIsUnit, additionalSignedIsUnit {
                classifications.append("\(identifier): unit")
                continue
            }

            if additionalSignedIsUnit, encoder.canEncodeOptional(for: String(signedExtension.type)) {
                classifications.append("\(identifier): nullable")
                continue
            }

            classifications.append("\(identifier): violation")

            violations.append(
                "\(identifier) declares extra \(typeName(for: signedExtension.type, in: metadata.types))" +
                    " and additional signed \(typeName(for: signedExtension.additionalSigned, in: metadata.types))"
            )
        }

        return SignedExtensionConformanceReport(classifications: classifications, violations: violations)
    }

    private func isUnitType(_ typeId: SiLookupId, in typesLookup: RuntimeTypesLookup) -> Bool {
        guard let portableType = typesLookup.types.first(where: { $0.identifier == typeId }) else {
            return false
        }

        switch portableType.type.typeDefinition {
        case let .composite(composite):
            return composite.fields.allSatisfy { isUnitType($0.type, in: typesLookup) }
        case let .tuple(tuple):
            return tuple.components.allSatisfy { isUnitType($0, in: typesLookup) }
        default:
            return false
        }
    }

    private func typeName(for typeId: SiLookupId, in typesLookup: RuntimeTypesLookup) -> String {
        let portableType = typesLookup.types.first(where: { $0.identifier == typeId })

        return portableType?.type.pathBasedName ?? String(typeId)
    }
}

private extension SignedExtensionConformanceTests {
    static let finneyNodes: [URL] = [
        URL(string: "wss://entrypoint-finney.opentensor.ai:443")!,
        URL(string: "wss://bittensor-finney.api.onfinality.io/public-ws")!
    ]

    static let finneyRuntime = Result { try RuntimeContext.setup(for: finneyNodes, chainName: "Bittensor") }

    static let pinnedTransactionExtensionSlots: [Set<String>] = [
        ["CheckNonZeroSender"],
        ["CheckSpecVersion"],
        ["CheckTxVersion"],
        ["CheckGenesis"],
        ["CheckMortality"],
        ["CheckNonce"],
        ["CheckWeight"],
        ["ChargeTransactionPayment", "ChargeTransactionPaymentWrapper"],
        ["SudoTransactionExtension"],
        ["CheckShieldedTxValidity"],
        ["SubtensorTransactionExtension"],
        ["DrandPriority"],
        ["CheckMetadataHash"]
    ]

    struct RuntimeContext {
        let connection: JSONRPCEngine
        let chainId: ChainModel.Id
        let genesisHash: String
        let metadata: PostV14RuntimeMetadataProtocol
        let codingFactory: RuntimeCoderFactoryProtocol

        static func setup(for nodes: [URL], chainName: String) throws -> RuntimeContext {
            guard let connection = WebSocketEngine(urls: nodes, logger: Logger.shared) else {
                throw SignedExtensionConformanceError.connectionUnavailable
            }

            let operationQueue = OperationQueue()

            let genesisHash = try fetchGenesisHash(from: connection, operationQueue: operationQueue)
            let chainId = genesisHash.withoutHexPrefix()

            let rawMetadata = try fetchRawMetadata(for: chainId, connection: connection, operationQueue: operationQueue)

            let chain = RuntimeProviderChain(
                chainId: chainId,
                typesUsage: .none,
                name: chainName,
                isEthereumBased: false
            )

            let registryInfo = try RuntimeTypeRegistryFactory(logger: Logger.shared).createForMetadataAndDefaultTyping(
                chain: chain,
                runtimeMetadataItem: rawMetadata
            )

            guard let metadata = registryInfo.runtimeMetadata as? PostV14RuntimeMetadataProtocol else {
                throw SignedExtensionConformanceError.legacyRuntimeNotSupported
            }

            let codingFactory = RuntimeCoderFactory(
                catalog: registryInfo.typeRegistryCatalog,
                specVersion: 0,
                txVersion: 0,
                metadata: registryInfo.runtimeMetadata
            )

            return RuntimeContext(
                connection: connection,
                chainId: chainId,
                genesisHash: genesisHash,
                metadata: metadata,
                codingFactory: codingFactory
            )
        }

        private static func fetchGenesisHash(
            from connection: JSONRPCEngine,
            operationQueue: OperationQueue
        ) throws -> String {
            let operation = BlockHashOperationFactory().createBlockHashOperation(
                connection: connection,
                for: { 0 }
            )

            operationQueue.addOperations([operation], waitUntilFinished: true)

            return try operation.extractNoCancellableResultData()
        }

        private static func fetchRawMetadata(
            for chainId: ChainModel.Id,
            connection: JSONRPCEngine,
            operationQueue: OperationQueue
        ) throws -> RawRuntimeMetadata {
            let wrapper = RuntimeFetchOperationFactory(operationQueue: operationQueue).createMetadataFetchWrapper(
                for: chainId,
                connection: connection
            )

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }
}

private struct SignedExtensionConformanceReport {
    let classifications: [String]
    let violations: [String]
}

private enum SignedExtensionConformanceError: Error {
    case connectionUnavailable
    case legacyRuntimeNotSupported
    case builderExtensionsUnavailable
}
