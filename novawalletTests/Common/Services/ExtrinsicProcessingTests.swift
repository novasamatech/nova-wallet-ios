import XCTest
@testable import novawallet
import NovaCrypto

class ExtrinsicProcessingTests: XCTestCase {
    let transferExtrinsicHex = "0x4102840080b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb995010560186586c0d7eeea6d43cc436d44565b44deedff523af37258d8577e68338f65e0faf9b00631e8389ecdf16d9b5493d1fc5d657d34ccf7bdc4ddf3db2572e009383f502040004000006c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d50070088526a74"

    let extrinsicIndex: UInt32 = 2

    let eventRecordsHex = "0x2400000000000000d8c873090000000002000000010000002c01d0070000e0e99e84fb05edab357d96ecee93ceff227fe6210b5fcf5b0b9629749c84fef74c555c145a593042734ee63a54f63266a45a7640627592ef4e4e8f22f952bd651a96dbb28d16701dbe7379c3ea39ddc0d22499ab3f08921ffd30bbe3747317ac66f7c7ca531901c8a6122c14de98048b2bcd631f474cf4de05e84a4c68f8dc9df8eabfb1d8319c75bd4be0d55aeffdd33c75689345654f7e88e53d0f815707f6f4c04b02271507bbcfa48eb1585a693124a96c0a645350bdd217be12483f331187ba3724ed1c71decc6aef3bd92f1bf42a7edea447c391a300724111e945138a92b3b8046c826054769beee09745a40383088534dafbbb2a0f0572add3dd01fbe3b12c1aef498e0582b1310c7c9cae566255c07bad4604b0c72e3cbc29e7a2df784bbfb3108e2e9bb3be392c539888ce1943d779a60c6d215b5bd0f19ce9537ae9020a0d0bae04a9e3b8c6347d29b0e6c910cd7b2f6f0451e0ad3e50863e6dd76cef8e7039004d39f79506074615dbcda5fbddd35808d5563f56094e0814301cb9ee3e272fc5c2a35fb6ddca55b6c03c8c32e6c4161f0584f3731f60b064308ab98d1d068ecf08066175726120ba5d3c080000000005617572610101c2a9fb2d50fe38a04c63fa6a4f81bc959de2e22bc8874474aaad7b837c2cb16da3959cab8e998c19268d7552f97631290d9a200bd4be1de86f612656e8ad9a8502000000020000000000010000002c00e8030000ea3c7b148597f5abb0af9676f1981063b8874fb39250ccc0decd2a4ea4bf595b8cd7b040a98f1df3ead0e2e88f873368c5d925f6048b34f2cb852614ea5f637742f79e3aae2993ebe8728947e1a8052c20e15d29337332aea848f946095513b76d9a7d3cb19276196e3cb4bd461e0c7fe89e78be92541dbc774060f00d7578a1fdf9c34daca5aeb9d1d6eea72022d05c0fce4228ff612a0620fdee83ca4924c048e6eccb1f3eb8e1eb4e9ab65bcccc54643f386ad06313191e3fee8ca710811e2b3d60f83b7aaae7c56e0088e6adecd2cb3bb8a39ee003481aa4b536ae0ce48c0e858cb1e82c2a85af578a719cc9ad6615a800efefdcc4fd86f0504732e66fc99b699850b78cf778fa194c709e3130db8596fd6a2ca49d8cf922404dd7f08b9bd1ea57a120e5bd2c08952301be2194acb882b4ef0405c4dbe440c58f83fa69dde9021031c2c6f9703686fc07b851385cfe16ef6bed4176632bda63a068651b632a548a0f9e00517f514922189a701e22223bded672e00d3b493a121b36dc7442923fe08bf6dbda953439ff233d37e09702acd41ac21bbf62695e3f691ae96ccd21fd0de275e208066175726120ba5d3c08000000000561757261010114892ca76804e18f2f99e1c00cf8b8765e477dc0777f1c2665c8892711a0ff3bae865e791f20299a5988f8c3798b24ad785a7e3eb585e892f70cb30a7d7b7c8f0000000000000000000001000000000030bd080e0b0000000200000002000000040880b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb9950105612d121ae030000000000000000000000000002000000040280b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb9950105606c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d500088526a740000000000000000000000000002000000040708270e4436898c595fe5f85a2fe671ba028b35be25c83fd58758ef564205111312d121ae0300000000000000000000000000020000001a0080b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb9950105612d121ae030000000000000000000000000000000000000000000000000000000000020000000000e83fba0900000000000000"

    let transferSender = "5EyUh8GXcbqPaPMwz4D5nNCFetogephAu3GQZZZjoTyJvPUK"
    let transferReceiver = "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn"

    func testTransferSuccessfullProcessing() {
        do {
            let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
            let senderAccountId = try transferSender.toAccountId()
            let receiverAccountId = try transferReceiver.toAccountId()

            let coderFactory = try RuntimeCodingServiceStub.createWestendCodingFactory(specVersion: 9260, txVersion: 11)
            let processor = ExtrinsicProcessor(accountId: senderAccountId, chain: chain)

            let eventRecordsData = try Data(hexString: eventRecordsHex)
            let typeName = coderFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath)!.type.typeName
            let decoder = try coderFactory.createDecoder(from: eventRecordsData)
            let eventRecords: [EventRecord] = try decoder.read(of: typeName)

            let extrinsicData = try Data(hexString: transferExtrinsicHex)

            guard let result = processor.process(
                    extrinsicIndex: extrinsicIndex,
                    extrinsicData: extrinsicData,
                    eventRecords: eventRecords,
                    coderFactory: coderFactory
            ) else {
                XCTFail("Unexpected empty result")
                return
            }

            XCTAssertEqual(.transfer, result.callPath)
            XCTAssertTrue(result.isSuccess)

            guard let fee = result.fee else {
                XCTFail("Missing fee")
                return
            }

            XCTAssertTrue(fee > 0)

            XCTAssertEqual(receiverAccountId, result.peerId)

        } catch {
            XCTFail("Did receiver error: \(error)")
        }
    }
}
