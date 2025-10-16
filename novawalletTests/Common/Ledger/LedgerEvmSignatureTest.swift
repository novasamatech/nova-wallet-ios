import XCTest
@testable import novawallet

final class LedgerEvmSignatureTest: XCTestCase {
    func testEvmSignature() throws {
        // given

        let publicKey = try Data(hexString: "0220fa18fd53d7899d8d7c0655d3f953ffd87d8ded0308992fe419aee2135a7019")
        let originalData = try Data(hexString: "0a0044625b6a493ec6e00166fc21ff7a1ee07eb8ee4a1300008a5d784563011502080001f803000001000000f6ee56e9c5277df5b4ce6ae9983ee88f3cbed27d31beeb98f9f84f997a1ab0b99492c020778e60144fa17b1613b64b69153ff73fb09013f9523fcd154b4b3cf90156b3798719581101b631b05c8254e02d00aa0dbef267822f1b1b99a563c53df8")

        let signature = try Data(hexString: "e650a0a9333df0f609f17388d79162cfe989f27479982129efcc65b0d5294a027fb9c692e502720ea339212c93ce5bbc849b89700ed8a1c6b344932fd1be5c1f00")

        // when

        let verifier = SignatureVerificationWrapper()

        let resultSignature = try verifier.verify(
            rawSignature: signature,
            originalData: originalData,
            rawPublicKey: publicKey,
            cryptoType: .ethereumEcdsa
        )

        XCTAssertNotNil(resultSignature)
    }
}
