import XCTest
@testable import novawallet
import SubstrateSdk
import Operation_iOS
import JavaScriptCore

final class DAppBrowserCreateTransactionTests: XCTestCase {
    let requestId = "1763625600000.7"
    let dAppUrl = "https://dapp.io/transfer"
    let genesisHash = "0x0bd72c1c305172e1275278aaeb3f161e02eccb7a819e63f62d47bd53a28189f8"

    // MARK: Authorized state

    func testEmitsSigningRequestForWalletSigner() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let signer = try setup.accountId.toAddress(using: setup.chain.chainFormat)
        let request = try createRequest(signer: signer)

        // when

        setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

        // then

        try assertSigningRequest(in: setup, operationData: request)
    }

    func testEmitsSigningRequestForMissingSigner() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let request = try createRequest(signer: nil)

        // when

        setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

        // then

        try assertSigningRequest(in: setup, operationData: request)
    }

    func testAcceptsSignerInGenericAndHexFormats() throws {
        let accountId = try XCTUnwrap(Data.random(of: 32))

        let signers = [
            try accountId.toAddress(using: .defaultSubstrateFormat),
            accountId.toHex(includePrefix: true),
            accountId.toHex(includePrefix: true).uppercased().replacingOccurrences(of: "0X", with: "0x")
        ]

        try signers.forEach { signer in
            // given

            let setup = try AuthorizedSetup(genesisHash: genesisHash, accountId: accountId, addressPrefix: 0)
            let request = try createRequest(signer: signer)

            // when

            setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

            // then

            try assertSigningRequest(in: setup, operationData: request)
        }
    }

    func testRespondsSignerUnavailableForUnknownGenesisHash() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let unknownGenesisHash = try XCTUnwrap(Data.random(of: 32)).toHex(includePrefix: true)
        let request = try createRequest(signer: nil, genesisHash: unknownGenesisHash)

        // when

        setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

        // then

        try assertErrorResponse(in: setup.stateMachine, name: "SignerUnavailable")
        XCTAssertTrue(setup.stateMachine.lastState is DAppBrowserAuthorizedState)
    }

    func testRespondsSignerUnavailableForForeignSigner() throws {
        let foreignAccountId = try XCTUnwrap(Data.random(of: 32))

        let signers = [
            try foreignAccountId.toAddress(using: .defaultSubstrateFormat),
            foreignAccountId.toHex(includePrefix: true),
            "not an address"
        ]

        try signers.forEach { signer in
            // given

            let setup = try AuthorizedSetup(genesisHash: genesisHash)
            let request = try createRequest(signer: signer)

            // when

            setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

            // then

            let message = try assertErrorResponse(in: setup.stateMachine, name: "SignerUnavailable")
            XCTAssertTrue(message.contains(signer))
            XCTAssertTrue(setup.stateMachine.lastState is DAppBrowserAuthorizedState)
        }
    }

    func testRespondsSignerUnavailableWhenWalletHasNoAccountForChain() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash, isEthereumBased: true)
        let request = try createRequest(signer: nil)

        // when

        setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

        // then

        try assertErrorResponse(in: setup.stateMachine, name: "SignerUnavailable")
    }

    func testRespondsDecodeErrorForUnsupportedVersion() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let request = try createRequest(signer: nil, version: 2)

        // when

        setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

        // then

        let message = try assertErrorResponse(in: setup.stateMachine, name: "DecodeError")
        XCTAssertTrue(message.contains("version 2"))
        XCTAssertTrue(setup.stateMachine.lastState is DAppBrowserAuthorizedState)
    }

    func testRespondsDecodeErrorForMalformedPayload() throws {
        let requests: [JSON?] = [
            nil,
            .stringValue("0x00"),
            try createJson(from: #"{ "version": 1, "extensions": [], "context": {} }"#)
        ]

        try requests.forEach { request in
            // given

            let setup = try AuthorizedSetup(genesisHash: genesisHash)

            // when

            setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

            // then

            try assertErrorResponse(in: setup.stateMachine, name: "DecodeError")
            XCTAssertTrue(setup.stateMachine.lastState is DAppBrowserAuthorizedState)
        }
    }

    // MARK: Signing state

    func testRespondsWithExtrinsicHex() throws {
        // given

        let stateMachine = DAppBrowserStateMachineRecorder()
        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let state = createSigningState(for: .createTransaction(chain: setup.chain), stateMachine: stateMachine)
        let extrinsic = try XCTUnwrap(Data.random(of: 140))

        // when

        state.handleOperation(
            response: DAppOperationResponse(createTransactionResult: .success(extrinsic)),
            dataSource: setup.dataSource
        )

        // then

        let extrinsicHex = extrinsic.toHex(includePrefix: true)

        XCTAssertEqual(
            stateMachine.responses.map(\.content),
            ["window.walletExtension.onAppResponse(\"\(requestId)\", \"\(extrinsicHex)\", null)"]
        )

        let appResponse = try evaluateAppResponse(from: stateMachine)
        XCTAssertEqual(appResponse.requestId, requestId)
        XCTAssertEqual(appResponse.result, extrinsicHex)
        XCTAssertNil(appResponse.errorMessage)
        XCTAssertTrue(stateMachine.lastState is DAppBrowserAuthorizedState)
    }

    func testRespondsWithNamedErrorForCreateTransactionFailure() throws {
        // given

        let stateMachine = DAppBrowserStateMachineRecorder()
        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let state = createSigningState(for: .createTransaction(chain: setup.chain), stateMachine: stateMachine)
        let error = DAppCreateTransactionError.missingMandatoryExtension(details: "AsScarcity")

        // when

        state.handleOperation(
            response: DAppOperationResponse(createTransactionResult: .failure(error)),
            dataSource: setup.dataSource
        )

        // then

        let expectedScript = "window.walletExtension.onAppResponse(\"\(requestId)\", null, "
            + "new Error(\"MissingMandatoryExtension: AsScarcity\"))"

        XCTAssertEqual(stateMachine.responses.map(\.content), [expectedScript])

        let appResponse = try evaluateAppResponse(from: stateMachine)
        XCTAssertEqual(appResponse.requestId, requestId)
        XCTAssertNil(appResponse.result)
        XCTAssertEqual(appResponse.errorMessage, "MissingMandatoryExtension: AsScarcity")
        XCTAssertTrue(stateMachine.lastState is DAppBrowserAuthorizedState)
    }

    func testProvidesAllErrorNamesInResponseMessage() {
        XCTAssertEqual(
            DAppCreateTransactionError.unsupportedTxExtensionVersion(details: "1").responseMessage,
            "UnsupportedTxExtensionVersion: 1"
        )
        XCTAssertEqual(
            DAppCreateTransactionError.missingMandatoryExtension(details: "2").responseMessage,
            "MissingMandatoryExtension: 2"
        )
        XCTAssertEqual(DAppCreateTransactionError.decodeError(details: "3").responseMessage, "DecodeError: 3")
        XCTAssertEqual(
            DAppCreateTransactionError.signerUnavailable(details: "4").responseMessage,
            "SignerUnavailable: 4"
        )
    }

    func testEscapesErrorDetailsInResponseScript() throws {
        let detailsList = [
            "quote \" and 'single'",
            "backslash \\ and trailing \\",
            "line\nbreak\r\nand\ttab",
            "\")); window.injected = true; ((\"",
            "separators \u{2028} and \u{2029}",
            "</script><script>window.injected = true</script>"
        ]

        try detailsList.forEach { details in
            // given

            let stateMachine = DAppBrowserStateMachineRecorder()
            let setup = try AuthorizedSetup(genesisHash: genesisHash)
            let state = createSigningState(for: .createTransaction(chain: setup.chain), stateMachine: stateMachine)
            let error = DAppCreateTransactionError.decodeError(details: details)

            // when

            state.handleOperation(
                response: DAppOperationResponse(createTransactionResult: .failure(error)),
                dataSource: setup.dataSource
            )

            // then

            let appResponse = try evaluateAppResponse(from: stateMachine)
            XCTAssertEqual(appResponse.errorMessage, "DecodeError: \(details)")
            XCTAssertFalse(appResponse.hasInjectedCode)
        }
    }

    func testEscapesSignerInAuthorizedStateErrorResponse() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let signer = "\")); window.injected = true; ((\"\n\\"
        let request = try createRequest(signer: signer)

        // when

        setup.state.handle(message: createMessage(with: request), dataSource: setup.dataSource)

        // then

        let appResponse = try evaluateAppResponse(from: setup.stateMachine)
        let errorMessage = try XCTUnwrap(appResponse.errorMessage)
        XCTAssertTrue(errorMessage.hasPrefix("SignerUnavailable: "))
        XCTAssertTrue(errorMessage.contains(signer))
        XCTAssertFalse(appResponse.hasInjectedCode)
    }

    func testRespondsRejectedForCreateTransactionRejection() throws {
        // given

        let stateMachine = DAppBrowserStateMachineRecorder()
        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let state = createSigningState(for: .createTransaction(chain: setup.chain), stateMachine: stateMachine)

        // when

        state.handleOperation(
            response: DAppOperationResponse(signature: nil, modifiedTransaction: nil),
            dataSource: setup.dataSource
        )

        // then

        XCTAssertEqual(stateMachine.responses.map(\.content), [rejectedScript])
        XCTAssertTrue(stateMachine.lastState is DAppBrowserAuthorizedState)
    }

    func testNeverRespondsWithSignatureForCreateTransaction() throws {
        // given

        let stateMachine = DAppBrowserStateMachineRecorder()
        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let state = createSigningState(for: .createTransaction(chain: setup.chain), stateMachine: stateMachine)
        let signature = try XCTUnwrap(Data.random(of: 64))

        // when

        state.handleOperation(
            response: DAppOperationResponse(signature: signature, modifiedTransaction: nil),
            dataSource: setup.dataSource
        )

        // then

        XCTAssertEqual(stateMachine.responses.map(\.content), [rejectedScript])
    }

    // MARK: Signing state regression for signPayload

    func testKeepsSignerResultForExtrinsicSigning() throws {
        // given

        let stateMachine = DAppBrowserStateMachineRecorder()
        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let state = createSigningState(for: .extrinsic(chain: setup.chain), stateMachine: stateMachine)
        let signature = try XCTUnwrap(Data.random(of: 65))
        let modifiedTransaction = try XCTUnwrap(Data.random(of: 120))

        // when

        state.handleOperation(
            response: DAppOperationResponse(signature: signature, modifiedTransaction: modifiedTransaction),
            dataSource: setup.dataSource
        )

        // then

        let result = try extractSignerResultJson(from: stateMachine)

        XCTAssertEqual(Set(result.keys), ["id", "signature", "signedTransaction"])
        XCTAssertTrue(result["id"] is NSNumber)
        XCTAssertEqual(result["signature"] as? String, signature.toHex(includePrefix: true))
        XCTAssertEqual(result["signedTransaction"] as? String, modifiedTransaction.toHex(includePrefix: true))
        XCTAssertTrue(stateMachine.lastState is DAppBrowserAuthorizedState)
    }

    func testKeepsSignerResultWithoutModifiedTransaction() throws {
        // given

        let stateMachine = DAppBrowserStateMachineRecorder()
        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let state = createSigningState(for: .extrinsic(chain: setup.chain), stateMachine: stateMachine)
        let signature = try XCTUnwrap(Data.random(of: 65))

        // when

        state.handleOperation(
            response: DAppOperationResponse(signature: signature, modifiedTransaction: nil),
            dataSource: setup.dataSource
        )

        // then

        let result = try extractSignerResultJson(from: stateMachine)

        XCTAssertEqual(Set(result.keys), ["id", "signature"])
        XCTAssertEqual(result["signature"] as? String, signature.toHex(includePrefix: true))
    }

    func testKeepsRejectedResponseForExtrinsicSigning() throws {
        // given

        let setup = try AuthorizedSetup(genesisHash: genesisHash)
        let extrinsic = try XCTUnwrap(Data.random(of: 140))

        let responses = [
            DAppOperationResponse(signature: nil, modifiedTransaction: nil),
            // a createTransaction result must never be taken for a signature
            DAppOperationResponse(createTransactionResult: .success(extrinsic))
        ]

        responses.forEach { response in
            let stateMachine = DAppBrowserStateMachineRecorder()
            let state = createSigningState(for: .extrinsic(chain: setup.chain), stateMachine: stateMachine)

            // when

            state.handleOperation(response: response, dataSource: setup.dataSource)

            // then

            XCTAssertEqual(stateMachine.responses.map(\.content), [rejectedScript])
            XCTAssertTrue(stateMachine.lastState is DAppBrowserAuthorizedState)
        }
    }
}

// MARK: Helpers

private extension DAppBrowserCreateTransactionTests {
    struct AuthorizedSetup {
        let stateMachine = DAppBrowserStateMachineRecorder()
        let state: DAppBrowserAuthorizedState
        let dataSource: DAppBrowserStateDataSource
        let chain: ChainModel
        let accountId: AccountId

        init(
            genesisHash: String,
            accountId: AccountId? = nil,
            addressPrefix: ChainModel.AddressPrefix = 42,
            isEthereumBased: Bool = false
        ) throws {
            let accountId = try accountId ?? XCTUnwrap(Data.random(of: 32))

            let wallet = MetaAccountModel(
                metaId: UUID().uuidString,
                name: "Test",
                substrateAccountId: accountId,
                substrateCryptoType: 0,
                substratePublicKey: accountId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .secrets,
                multisig: nil
            )

            chain = ChainModelGenerator.generateChain(
                defaultChainId: try Data(hexString: genesisHash).toHex(),
                generatingAssets: 1,
                addressPrefix: addressPrefix,
                isEthereumBased: isEthereumBased
            )

            let dAppSettingsRepository = UserDataStorageTestFacade().createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(DAppSettingsMapper())
            )

            dataSource = DAppBrowserStateDataSource(
                wallet: wallet,
                chainRegistry: MockChainRegistryProtocol(),
                dAppSettingsRepository: AnyDataProviderRepository(dAppSettingsRepository),
                operationQueue: OperationQueue(),
                tab: nil
            )

            dataSource.set(chain: chain, for: chain.chainId)

            self.accountId = accountId
            state = DAppBrowserAuthorizedState(stateMachine: stateMachine)
        }
    }

    struct AppResponse {
        let requestId: String?
        let result: String?
        let errorMessage: String?
        let hasInjectedCode: Bool
    }

    var rejectedScript: String {
        "window.walletExtension.onAppResponse(\"\(requestId)\", null, new Error(\"Rejected\"))"
    }

    func createJson(from string: String) throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: Data(string.utf8))
    }

    func createRequest(signer: String?, genesisHash: String? = nil, version: UInt = 1) throws -> JSON {
        let request: [String: Any] = [
            "version": version,
            "signer": signer ?? NSNull(),
            "callData": "0x0503001234",
            "extensions": [
                ["id": "CheckNonce", "extra": "0x04", "additionalSigned": "0x"]
            ],
            "txExtVersion": 0,
            "context": [
                "token": ["symbol": "DOT", "decimals": 10],
                "bestBlockHeight": 7_485_234,
                "bestBlockHash": "0x2fad67977d3e2235f745f88f8c4149182f9ee717f871dd5aa66a336049417221",
                "genesisHash": genesisHash ?? self.genesisHash
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: request)

        return try JSONDecoder().decode(JSON.self, from: data)
    }

    func createMessage(with request: JSON?) -> PolkadotExtensionMessage {
        PolkadotExtensionMessage(
            identifier: requestId,
            messageType: .createTransaction,
            request: request,
            url: dAppUrl
        )
    }

    func createSigningState(
        for signingType: DAppSigningType,
        stateMachine: DAppBrowserStateMachineRecorder
    ) -> DAppBrowserSigningState {
        DAppBrowserSigningState(stateMachine: stateMachine, signingType: signingType, requestId: requestId)
    }

    func assertSigningRequest(
        in setup: AuthorizedSetup,
        operationData: JSON,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let stateMachine = setup.stateMachine

        XCTAssertTrue(stateMachine.responses.isEmpty, file: file, line: line)
        XCTAssertTrue(stateMachine.errors.isEmpty, file: file, line: line)
        XCTAssertEqual(stateMachine.signingRequests.count, 1, file: file, line: line)

        let signing = try XCTUnwrap(stateMachine.signingRequests.first, file: file, line: line)

        guard case let .createTransaction(chain) = signing.type else {
            XCTFail("Unexpected signing type: \(signing.type)", file: file, line: line)
            return
        }

        XCTAssertEqual(chain.chainId, setup.chain.chainId, file: file, line: line)
        XCTAssertEqual(signing.request.transportName, DAppTransports.polkadotExtension, file: file, line: line)
        XCTAssertEqual(signing.request.identifier, requestId, file: file, line: line)
        XCTAssertEqual(signing.request.wallet.metaId, setup.dataSource.wallet.metaId, file: file, line: line)
        XCTAssertEqual(signing.request.accountId, setup.accountId, file: file, line: line)
        XCTAssertEqual(signing.request.dApp, dAppUrl, file: file, line: line)
        XCTAssertEqual(signing.request.operationData, operationData, file: file, line: line)

        let signingState = try XCTUnwrap(
            stateMachine.lastState as? DAppBrowserSigningState,
            file: file,
            line: line
        )

        XCTAssertEqual(signingState.requestId, requestId, file: file, line: line)

        guard case .createTransaction = signingState.signingType else {
            XCTFail("Unexpected state signing type: \(signingState.signingType)", file: file, line: line)
            return
        }
    }

    @discardableResult
    func assertErrorResponse(
        in stateMachine: DAppBrowserStateMachineRecorder,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        XCTAssertTrue(stateMachine.signingRequests.isEmpty, file: file, line: line)
        XCTAssertTrue(stateMachine.errors.isEmpty, file: file, line: line)

        let appResponse = try evaluateAppResponse(from: stateMachine, file: file, line: line)

        XCTAssertEqual(appResponse.requestId, requestId, file: file, line: line)
        XCTAssertNil(appResponse.result, file: file, line: line)

        let errorMessage = try XCTUnwrap(appResponse.errorMessage, file: file, line: line)

        // the bridge takes the error name with this pattern
        let namePattern = try NSRegularExpression(pattern: "^([A-Za-z]+): ")
        let range = NSRange(errorMessage.startIndex..., in: errorMessage)
        let match = try XCTUnwrap(
            namePattern.firstMatch(in: errorMessage, range: range),
            "No error name in: \(errorMessage)",
            file: file,
            line: line
        )
        let nameRange = try XCTUnwrap(Range(match.range(at: 1), in: errorMessage), file: file, line: line)

        XCTAssertEqual(String(errorMessage[nameRange]), name, file: file, line: line)

        return errorMessage
    }

    // Runs the only response script the way the web view does and returns what the bridge receives
    func evaluateAppResponse(
        from stateMachine: DAppBrowserStateMachineRecorder,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> AppResponse {
        XCTAssertEqual(stateMachine.responses.count, 1, file: file, line: line)

        let script = try XCTUnwrap(stateMachine.responses.first?.content, file: file, line: line)
        let context = try XCTUnwrap(JSContext(), file: file, line: line)

        context.evaluateScript(
            """
            var calls = [];
            var window = {
                walletExtension: {
                    onAppResponse: function (id, result, error) {
                        calls.push({
                            id: id,
                            result: result,
                            error: error instanceof Error ? error.message : null
                        });
                    }
                }
            };
            """
        )

        context.evaluateScript(script)

        XCTAssertNil(context.exception, "Script failed: \(script)", file: file, line: line)

        let calls = try XCTUnwrap(context.objectForKeyedSubscript("calls"), file: file, line: line)

        XCTAssertEqual(calls.forProperty("length").toInt32(), 1, file: file, line: line)

        let call = try XCTUnwrap(calls.atIndex(0), file: file, line: line)
        let injected = try XCTUnwrap(context.evaluateScript("window.injected"), file: file, line: line)

        return AppResponse(
            requestId: call.forProperty("id").toOptionalString(),
            result: call.forProperty("result").toOptionalString(),
            errorMessage: call.forProperty("error").toOptionalString(),
            hasInjectedCode: !injected.isUndefined
        )
    }

    func extractSignerResultJson(
        from stateMachine: DAppBrowserStateMachineRecorder,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        XCTAssertEqual(stateMachine.responses.count, 1, file: file, line: line)

        let script = try XCTUnwrap(stateMachine.responses.first?.content, file: file, line: line)
        let prefix = "window.walletExtension.onAppResponse(\"\(requestId)\", "
        let suffix = ", null)"

        XCTAssertTrue(script.hasPrefix(prefix), script, file: file, line: line)
        XCTAssertTrue(script.hasSuffix(suffix), script, file: file, line: line)

        let json = String(script.dropFirst(prefix.count).dropLast(suffix.count))
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))

        // the dApp side expects exactly the encoded PolkadotExtensionSignerResult
        _ = try JSONDecoder().decode(PolkadotExtensionSignerResult.self, from: Data(json.utf8))

        return try XCTUnwrap(object as? [String: Any], file: file, line: line)
    }
}

private extension JSValue {
    func toOptionalString() -> String? {
        isNull || isUndefined ? nil : toString()
    }
}

final class DAppBrowserStateMachineRecorder: DAppBrowserStateMachineProtocol {
    struct SigningRequest {
        let request: DAppOperationRequest
        let type: DAppSigningType
    }

    private(set) var responses: [DAppScriptResponse] = []
    private(set) var signingRequests: [SigningRequest] = []
    private(set) var authRequests: [DAppAuthRequest] = []
    private(set) var errors: [Error] = []
    private(set) var lastState: DAppBrowserStateProtocol?

    func emit(nextState: DAppBrowserStateProtocol) {
        lastState = nextState
    }

    func emit(response: DAppScriptResponse, nextState: DAppBrowserStateProtocol) {
        responses.append(response)
        lastState = nextState
    }

    func emit(authRequest: DAppAuthRequest, nextState: DAppBrowserStateProtocol) {
        authRequests.append(authRequest)
        lastState = nextState
    }

    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: DAppBrowserStateProtocol
    ) {
        signingRequests.append(SigningRequest(request: signingRequest, type: type))
        lastState = nextState
    }

    func emit(error: Error, nextState: DAppBrowserStateProtocol) {
        errors.append(error)
        lastState = nextState
    }

    func popMessage() {}
}
