import JavaScriptCore
@testable import novawallet
import XCTest

/// The request id arrives from the page as any other field of a message, so the scripts that answer it
/// must keep it inside the argument whatever it contains.
final class DAppBrowserRequestIdTests: XCTestCase {
    private static let hostileIds = [
        "quote \" and 'single'",
        "backslash \\ and trailing \\",
        "line\nbreak\r\nand\ttab",
        "\", null, null); window.injected = true; window.walletExtension.onAppResponse(\"",
        "\"); window.injected = true; (\"",
        "separators \u{2028} and \u{2029}",
        "</script><script>window.injected = true</script>"
    ]

    func testResponseKeepsRequestIdInsideItsArgument() throws {
        for requestId in Self.hostileIds {
            // given

            let stateMachine = DAppBrowserStateMachineRecorder()
            let state = DAppBrowserBaseState(stateMachine: stateMachine)

            // when

            try state.provideResponse(
                for: requestId,
                result: true,
                nextState: DAppBrowserAuthorizedState(stateMachine: stateMachine)
            )

            // then

            let call = try evaluateSingleCall(from: stateMachine)

            XCTAssertEqual(call.function, "onAppResponse")
            XCTAssertEqual(call.requestId, requestId)
            XCTAssertEqual(call.payload, "true")
            XCTAssertFalse(call.hasInjectedCode)
        }
    }

    func testErrorKeepsRequestIdInsideItsArgument() throws {
        for requestId in Self.hostileIds {
            // given

            let stateMachine = DAppBrowserStateMachineRecorder()
            let state = DAppBrowserBaseState(stateMachine: stateMachine)

            // when

            state.provideError(
                for: requestId,
                errorMessage: "Rejected",
                nextState: DAppBrowserAuthorizedState(stateMachine: stateMachine)
            )

            // then

            let call = try evaluateSingleCall(from: stateMachine)

            XCTAssertEqual(call.function, "onAppResponse")
            XCTAssertEqual(call.requestId, requestId)
            XCTAssertEqual(call.payload, "Rejected")
            XCTAssertFalse(call.hasInjectedCode)
        }
    }

    func testSubscriptionKeepsRequestIdInsideItsArgument() throws {
        for requestId in Self.hostileIds {
            // given

            let stateMachine = DAppBrowserStateMachineRecorder()
            let state = DAppBrowserBaseState(stateMachine: stateMachine)

            // when

            try state.provideSubscription(
                for: requestId,
                result: true,
                nextState: DAppBrowserAuthorizedState(stateMachine: stateMachine)
            )

            // then

            let call = try evaluateSingleCall(from: stateMachine)

            XCTAssertEqual(call.function, "onAppSubscription")
            XCTAssertEqual(call.requestId, requestId)
            XCTAssertEqual(call.payload, "true")
            XCTAssertFalse(call.hasInjectedCode)
        }
    }

    func testOrdinaryRequestIdKeepsTheScriptsUnchanged() throws {
        // given

        let requestId = "1763625600000.7"
        let stateMachine = DAppBrowserStateMachineRecorder()
        let state = DAppBrowserBaseState(stateMachine: stateMachine)
        let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)

        // when

        try state.provideResponse(for: requestId, result: true, nextState: nextState)
        state.provideError(for: requestId, errorMessage: "Rejected", nextState: nextState)
        try state.provideSubscription(for: requestId, result: true, nextState: nextState)

        // then

        XCTAssertEqual(
            stateMachine.responses.map(\.content),
            [
                "window.walletExtension.onAppResponse(\"1763625600000.7\", true, null)",
                "window.walletExtension.onAppResponse(\"1763625600000.7\", null, new Error(\"Rejected\"))",
                "window.walletExtension.onAppSubscription(\"1763625600000.7\", true)"
            ]
        )
    }
}

private extension DAppBrowserRequestIdTests {
    struct BridgeCall {
        let function: String?
        let requestId: String?
        let payload: String?
        let hasInjectedCode: Bool
    }

    // Runs the only script the way the web view does and returns what the bridge receives
    func evaluateSingleCall(from stateMachine: DAppBrowserStateMachineRecorder) throws -> BridgeCall {
        XCTAssertTrue(stateMachine.errors.isEmpty)
        XCTAssertEqual(stateMachine.responses.count, 1)

        let script = try XCTUnwrap(stateMachine.responses.first?.content)
        let context = try XCTUnwrap(JSContext())

        context.evaluateScript(
            """
            var calls = [];
            var window = {
                walletExtension: {
                    onAppResponse: function (id, result, error) {
                        var payload = error instanceof Error ? error.message : JSON.stringify(result);
                        calls.push({ name: "onAppResponse", id: id, payload: payload });
                    },
                    onAppSubscription: function (id, result) {
                        calls.push({ name: "onAppSubscription", id: id, payload: JSON.stringify(result) });
                    }
                }
            };
            """
        )

        context.evaluateScript(script)

        XCTAssertNil(context.exception, "Script failed: \(script)")

        let calls = try XCTUnwrap(context.objectForKeyedSubscript("calls"))

        XCTAssertEqual(calls.forProperty("length").toInt32(), 1)

        let call = try XCTUnwrap(calls.atIndex(0))
        let injected = try XCTUnwrap(context.evaluateScript("window.injected"))

        return BridgeCall(
            function: call.forProperty("name").toString(),
            requestId: call.forProperty("id").toString(),
            payload: call.forProperty("payload").toString(),
            hasInjectedCode: !injected.isUndefined
        )
    }
}
