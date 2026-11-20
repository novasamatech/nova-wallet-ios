import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins the JSON model the app gets when it decodes extrinsics and event records (transaction history,
/// extrinsic processing, fee estimation and multisig call data all start from it).
/// Golden values were recorded on substrate-sdk-ios 4.5.2.
final class ExtrinsicDecodingCharacterizationTests: XCTestCase {
    /// Real Westend extrinsic and block events, shared with `ExtrinsicProcessingTests`.
    private let onChainFixture = ExtrinsicProcessingTests()

    private var runtime: ExtrinsicGoldenRuntime!

    override func setUpWithError() throws {
        runtime = try ExtrinsicGoldenRuntime.westend()
    }

    func testOnChainSignedTransferDecodesToJson() throws {
        let extrinsic = try runtime.decodeExtrinsic(onChainFixture.transferExtrinsicHex)

        XCTAssertEqual(try ExtrinsicGolden.json(extrinsic), #"{"signed":{"_0":{"call":{"args":{"dest":["Id","0x06c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d50"],"value":"500000000000"},"callName":"transfer","moduleName":"Balances"},"signature":{"address":["Id","0x80b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb99501056"],"extra":{"ChargeTransactionPayment":"0","CheckGenesis":{},"CheckMortality":[1,64,47],"CheckNonZeroSender":{},"CheckNonce":"1","CheckSpecVersion":{},"CheckTxVersion":{},"CheckWeight":{}},"signature":["Sr25519",["134","88","108","13","126","238","166","212","60","196","54","212","69","101","180","77","238","223","245","35","175","55","37","141","133","119","230","131","56","246","94","15","175","155","0","99","30","131","137","236","223","22","217","181","73","61","31","197","214","87","211","76","207","123","220","77","223","61","178","87","46","0","147","131"]]}}}}"#)
    }

    func testOnChainSignedTransferMapsToAppModels() throws {
        let extrinsic = try runtime.decodeExtrinsic(onChainFixture.transferExtrinsicHex)
        let signed = try XCTUnwrap(extrinsic.getSignedExtrinsic())
        let context = runtime.codingFactory.createRuntimeJsonContext().toRawContext()

        let sender = try signed.signature.address.map(to: MultiAddress.self, with: context).accountId
        let call = try extrinsic.call.map(to: RuntimeCall<TransferCall>.self, with: context)
        let signature = try signed.signature.signature.map(to: MultiSignature.self, with: context)

        XCTAssertNil(extrinsic.getBareExtrinsic())
        XCTAssertEqual(sender, try onChainFixture.transferSender.toAccountId())
        XCTAssertEqual(call.moduleName, "Balances")
        XCTAssertEqual(call.callName, "transfer")
        XCTAssertEqual(call.args.dest.accountId, try onChainFixture.transferReceiver.toAccountId())
        XCTAssertEqual(call.args.value, BigUInt(500_000_000_000))
        XCTAssertEqual(signed.signature.extra.getNonce(), 1)
        XCTAssertEqual(signed.signature.extra.getTip(), 0)
        XCTAssertEqual(signed.signature.extra.getEra(), .mortal(period: 64, phase: 47))

        guard case let .sr25519(data) = signature else {
            return XCTFail("Unexpected signature: \(signature)")
        }

        XCTAssertEqual(data.count, 64)
    }

    func testOnChainSignedTransferReencodesToSameBytes() throws {
        let extrinsic = try runtime.decodeExtrinsic(onChainFixture.transferExtrinsicHex)

        let encoder = runtime.codingFactory.createEncoder()
        try encoder.append(extrinsic, ofType: GenericType.extrinsic.name)

        XCTAssertEqual(try encoder.encode().toHex(includePrefix: true), onChainFixture.transferExtrinsicHex)
    }

    func testBareExtrinsicDecodesToJson() throws {
        let builder = try runtime.makeBuilder().adding(call: ExtrinsicGolden.remarkCall(size: 4))
        let bare = try builder.build(using: runtime.codingFactory, metadata: runtime.metadata)

        let extrinsic = try runtime.decodeExtrinsic(bare.toHex(includePrefix: true))

        XCTAssertNil(extrinsic.getSignedExtrinsic())
        XCTAssertNotNil(extrinsic.getBareExtrinsic())
        XCTAssertEqual(try ExtrinsicGolden.json(extrinsic), #"{"bare":{"_0":{"call":{"args":{"remark":["90","90","90","90"]},"callName":"remark","moduleName":"System"},"extrinsicVersion":4}}}"#)
    }

    func testSignedBatchDecodesToJson() throws {
        let builder = try runtime.makeBuilder()
            .adding(call: ExtrinsicGolden.transferCall())
            .adding(call: ExtrinsicGolden.remarkCall(size: 3))

        let extrinsic = try runtime.decodeExtrinsic(runtime.sign(builder).extrinsic)

        XCTAssertEqual(try ExtrinsicGolden.json(extrinsic), #"{"signed":{"_0":{"call":{"args":{"calls":[{"args":{"dest":["Id","0x2222222222222222222222222222222222222222222222222222222222222222"],"value":"1000000000000"},"callName":"transfer_keep_alive","moduleName":"Balances"},{"args":{"remark":["90","90","90"]},"callName":"remark","moduleName":"System"}]},"callName":"batch_all","moduleName":"Utility"},"signature":{"address":["Id","0x1111111111111111111111111111111111111111111111111111111111111111"],"extra":{"ChargeTransactionPayment":"0","CheckGenesis":{},"CheckMortality":[1,64,5],"CheckNonZeroSender":{},"CheckNonce":"7","CheckSpecVersion":{},"CheckTxVersion":{},"CheckWeight":{}},"signature":["Sr25519",["171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171","171"]]}}}}"#)
    }

    func testEcdsaAndEd25519SignaturesDecodeToMultiSignature() throws {
        let builder = try runtime.makeBuilder().adding(call: ExtrinsicGolden.transferCall())
        let ecdsaHex = try runtime.sign(builder, cryptoType: .ecdsa, signature: ExtrinsicGolden.ecdsaSignature).extrinsic
        let ed25519Hex = try runtime.sign(builder, cryptoType: .ed25519).extrinsic

        let ecdsa = try XCTUnwrap(runtime.decodeExtrinsic(ecdsaHex).getSignedExtrinsic()).signature.signature
        let ed25519 = try XCTUnwrap(runtime.decodeExtrinsic(ed25519Hex).getSignedExtrinsic()).signature.signature

        guard case let .ecdsa(ecdsaData) = try ecdsa.map(to: MultiSignature.self) else {
            return XCTFail("Ecdsa signature expected")
        }

        guard case let .ed25519(ed25519Data) = try ed25519.map(to: MultiSignature.self) else {
            return XCTFail("Ed25519 signature expected")
        }

        XCTAssertEqual(ecdsaData, ExtrinsicGolden.ecdsaSignature)
        XCTAssertEqual(ed25519Data, ExtrinsicGolden.sr25519Signature)
    }

    func testOnChainEventRecordsDecode() throws {
        let records = try decodeEventRecords()

        let summary = try records.map { record in
            let phase = record.extrinsicIndex.map { "extrinsic \($0)" } ?? "no extrinsic"
            let path = runtime.metadata.createEventCodingPath(from: record.event)
            let name = path.map { "\($0.moduleName).\($0.eventName)" } ?? "unknown"
            let params = try ExtrinsicGolden.json(record.event.params)

            return "\(phase)|\(record.event.moduleIndex):\(record.event.eventIndex)|\(name)|\(params)"
        }

        XCTAssertEqual(records.count, 9)
        XCTAssertEqual(summary.joined(separator: " ## "), #"extrinsic 0|0:0|System.ExtrinsicSuccess|[{"class":["Mandatory",null],"paysFee":["Yes",null],"weight":"158583000"}] ## extrinsic 1|44:1|ParaInclusion.CandidateIncluded|[{"commitmentsHash":["120","75","191","179","16","142","46","155","179","190","57","44","83","152","136","206","25","67","215","121","166","12","109","33","91","91","208","241","156","233","83","122"],"descriptor":{"collator":["76","85","92","20","90","89","48","66","115","78","230","58","84","246","50","102","164","90","118","64","98","117","146","239","78","78","143","34","249","82","189","101"],"erasureRoot":["248","234","191","177","216","49","156","117","189","75","224","213","90","239","253","211","60","117","104","147","69","101","79","126","136","229","61","15","129","87","7","246"],"paraHead":["146","179","184","4","108","130","96","84","118","155","238","224","151","69","164","3","131","8","133","52","218","251","187","42","15","5","114","173","211","221","1","251"],"paraId":"2000","persistedValidationDataHash":["26","150","219","178","141","22","112","29","190","115","121","195","234","57","221","192","210","36","153","171","63","8","146","31","253","48","187","227","116","115","23","172"],"povHash":["102","247","199","202","83","25","1","200","166","18","44","20","222","152","4","139","43","205","99","31","71","76","244","222","5","232","74","76","104","248","220","157"],"relayParent":["224","233","158","132","251","5","237","171","53","125","150","236","238","147","206","255","34","127","230","33","11","95","207","91","11","150","41","116","156","132","254","247"],"signature":["244","192","75","2","39","21","7","187","207","164","142","177","88","90","105","49","36","169","108","10","100","83","80","189","210","23","190","18","72","63","51","17","135","186","55","36","237","28","113","222","204","106","239","59","217","47","27","244","42","126","222","164","71","195","145","163","0","114","65","17","233","69","19","138"],"validationCodeHash":["227","177","44","26","239","73","142","5","130","177","49","12","124","156","174","86","98","85","192","123","173","70","4","176","199","46","60","188","41","231","162","223"]}},["10","13","11","174","4","169","227","184","198","52","125","41","176","230","201","16","205","123","47","111","4","81","224","173","62","80","134","62","109","215","108","239","142","112","57","0","77","57","247","149","6","7","70","21","219","205","165","251","221","211","88","8","213","86","63","86","9","78","8","20","48","28","185","238","62","39","47","197","194","163","95","182","221","202","85","182","192","60","140","50","230","196","22","31","5","132","243","115","31","96","176","100","48","138","185","141","29","6","142","207","8","6","97","117","114","97","32","186","93","60","8","0","0","0","0","5","97","117","114","97","1","1","194","169","251","45","80","254","56","160","76","99","250","106","79","129","188","149","157","226","226","43","200","135","68","116","170","173","123","131","124","44","177","109","163","149","156","171","142","153","140","25","38","141","117","82","249","118","49","41","13","154","32","11","212","190","29","232","111","97","38","86","232","173","154","133"],"2","2"] ## extrinsic 1|44:0|ParaInclusion.CandidateBacked|[{"commitmentsHash":["209","234","87","161","32","229","189","44","8","149","35","1","190","33","148","172","184","130","180","239","4","5","196","219","228","64","197","143","131","250","105","221"],"descriptor":{"collator":["140","215","176","64","169","143","29","243","234","208","226","232","143","135","51","104","197","217","37","246","4","139","52","242","203","133","38","20","234","95","99","119"],"erasureRoot":["253","249","195","77","172","165","174","185","209","214","238","167","32","34","208","92","15","206","66","40","255","97","42","6","32","253","238","131","202","73","36","192"],"paraHead":["14","133","140","177","232","44","42","133","175","87","138","113","156","201","173","102","21","168","0","239","239","220","196","253","134","240","80","71","50","230","111","201"],"paraId":"1000","persistedValidationDataHash":["66","247","158","58","174","41","147","235","232","114","137","71","225","168","5","44","32","225","93","41","51","115","50","174","168","72","249","70","9","85","19","183"],"povHash":["109","154","125","60","177","146","118","25","110","60","180","189","70","30","12","127","232","158","120","190","146","84","29","188","119","64","96","240","13","117","120","161"],"relayParent":["234","60","123","20","133","151","245","171","176","175","150","118","241","152","16","99","184","135","79","179","146","80","204","192","222","205","42","78","164","191","89","91"],"signature":["72","230","236","203","31","62","184","225","235","78","154","182","91","204","204","84","100","63","56","106","208","99","19","25","30","63","238","140","167","16","129","30","43","61","96","248","59","122","170","231","197","110","0","136","230","173","236","210","203","59","184","163","158","224","3","72","26","164","181","54","174","12","228","140"],"validationCodeHash":["155","105","152","80","183","140","247","120","250","25","76","112","158","49","48","219","133","150","253","106","44","164","157","140","249","34","64","77","215","240","139","155"]}},["16","49","194","198","249","112","54","134","252","7","184","81","56","92","254","22","239","107","237","65","118","99","43","218","99","160","104","101","27","99","42","84","138","15","158","0","81","127","81","73","34","24","154","112","30","34","34","59","222","214","114","224","13","59","73","58","18","27","54","220","116","66","146","63","224","139","246","219","218","149","52","57","255","35","61","55","224","151","2","172","212","26","194","27","191","98","105","94","63","105","26","233","108","205","33","253","13","226","117","226","8","6","97","117","114","97","32","186","93","60","8","0","0","0","0","5","97","117","114","97","1","1","20","137","44","167","104","4","225","143","47","153","225","192","12","248","184","118","94","71","125","192","119","127","28","38","101","200","137","39","17","160","255","59","174","134","94","121","31","32","41","154","89","136","248","195","121","139","36","173","120","90","126","62","181","133","232","146","247","12","179","10","125","123","124","143"],"0","0"] ## extrinsic 1|0:0|System.ExtrinsicSuccess|[{"class":["Mandatory",null],"paysFee":["Yes",null],"weight":"47480094000"}] ## extrinsic 2|4:8|Balances.Withdraw|["0x80b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb99501056","15806353682"] ## extrinsic 2|4:2|Balances.Transfer|["0x80b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb99501056","0x06c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d50","500000000000"] ## extrinsic 2|4:7|Balances.Deposit|["0x08270e4436898c595fe5f85a2fe671ba028b35be25c83fd58758ef5642051113","15806353682"] ## extrinsic 2|26:0|TransactionPayment.TransactionFeePaid|["0x80b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb99501056","15806353682","0"] ## extrinsic 2|0:0|System.ExtrinsicSuccess|[{"class":["Normal",null],"paysFee":["Yes",null],"weight":"163201000"}]"#)
    }

    func testOnChainExtrinsicProcessingResult() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let sender = try onChainFixture.transferSender.toAccountId()
        let processor = ExtrinsicProcessor(accountId: sender, chain: chain)

        let result = try XCTUnwrap(
            processor.process(
                extrinsicIndex: onChainFixture.extrinsicIndex,
                extrinsicData: Data(hexString: onChainFixture.transferExtrinsicHex),
                eventRecords: decodeEventRecords(),
                coderFactory: runtime.codingFactory
            )
        )

        XCTAssertEqual(result.callPath, .transfer)
        XCTAssertEqual(result.sender, sender)
        XCTAssertEqual(result.peerId, try onChainFixture.transferReceiver.toAccountId())
        XCTAssertEqual(result.fee, BigUInt(15_806_353_682))
        XCTAssertEqual(result.amount, BigUInt(500_000_000_000))
        XCTAssertTrue(result.isSuccess)
    }
}

private extension ExtrinsicDecodingCharacterizationTests {
    func decodeEventRecords() throws -> [EventRecord] {
        let typeName = try XCTUnwrap(runtime.metadata.getStorageMetadata(for: SystemPallet.eventsPath)).type.typeName
        let decoder = try runtime.codingFactory.createDecoder(from: Data(hexString: onChainFixture.eventRecordsHex))

        return try decoder.read(of: typeName)
    }
}
