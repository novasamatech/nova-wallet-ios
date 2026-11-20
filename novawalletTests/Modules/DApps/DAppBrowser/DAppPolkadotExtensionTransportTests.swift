@testable import novawallet
import Operation_iOS
import XCTest

final class DAppPolkadotExtensionTransportTests: XCTestCase {
    func testFailureAnsweredWithoutScreenIsLoggedAndDelivered() throws {
        // given

        let logger = LoggerSpy()
        let delegate = TransportDelegateSpy()
        let transport = DAppPolkadotExtensionTransport(delegate: delegate, logger: logger)

        transport.start(with: try makeDataSource())

        let response = DAppScriptResponse(content: "window.walletExtension.onAppResponse(\"1\", null, null)")
        let nextState = DAppBrowserAuthorizedState(stateMachine: transport)

        // when

        transport.emit(
            failureResponse: response,
            reason: "SignerUnavailable: unsupported chain 0x00",
            nextState: nextState
        )

        // then

        XCTAssertEqual(
            logger.records,
            [.init(level: .warning, message: "DApp request failed: SignerUnavailable: unsupported chain 0x00")]
        )
        XCTAssertEqual(delegate.responses.map(\.content), [response.content])
        XCTAssertTrue(transport.state is DAppBrowserAuthorizedState)
    }

    func testOrdinaryResponseIsNotLogged() throws {
        // given

        let logger = LoggerSpy()
        let delegate = TransportDelegateSpy()
        let transport = DAppPolkadotExtensionTransport(delegate: delegate, logger: logger)

        transport.start(with: try makeDataSource())

        let response = DAppScriptResponse(content: "window.walletExtension.onAppResponse(\"1\", true, null)")

        // when

        transport.emit(response: response, nextState: DAppBrowserAuthorizedState(stateMachine: transport))

        // then

        XCTAssertEqual(logger.records, [])
        XCTAssertEqual(delegate.responses.map(\.content), [response.content])
    }
}

private extension DAppPolkadotExtensionTransportTests {
    func makeDataSource() throws -> DAppBrowserStateDataSource {
        let accountId = try XCTUnwrap(Data.random(of: 32))

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

        let dAppSettingsRepository = UserDataStorageTestFacade().createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(DAppSettingsMapper())
        )

        return DAppBrowserStateDataSource(
            wallet: wallet,
            chainRegistry: MockChainRegistryProtocol(),
            dAppSettingsRepository: AnyDataProviderRepository(dAppSettingsRepository),
            operationQueue: OperationQueue(),
            tab: nil
        )
    }
}

private final class TransportDelegateSpy: DAppBrowserTransportDelegate {
    private(set) var responses: [DAppScriptResponse] = []

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceiveResponse response: DAppScriptResponse) {
        responses.append(response)
    }

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceiveAuth _: DAppAuthRequest) {}

    func dAppTransport(
        _: DAppBrowserTransportProtocol,
        didReceiveConfirmation _: DAppOperationRequest,
        of _: DAppSigningType
    ) {}

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceive _: Error) {}

    func dAppTransportAsksPopMessage(_: DAppBrowserTransportProtocol) {}

    func dAppAskReload(_: DAppBrowserTransportProtocol, postExecutionScript _: DAppScriptResponse) {}
}
