import XCTest
import Operation_iOS
@testable import novawallet

private final class StubGlobalConfigProvider: GlobalConfigProviding {
    private let result: Result<GlobalConfig, Error>

    init(result: Result<GlobalConfig, Error>) {
        self.result = result
    }

    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
        let result = result

        return CompoundOperationWrapper(targetOperation: ClosureOperation { try result.get() })
    }
}

private enum StubConfigError: Error {
    case unreachable
}

/// The operator's emergency brake. A defect here fails open — analytics keeps running after
/// the switch is thrown — which is the failure mode nobody notices, so the join the adapter
/// performs is pinned directly rather than through `GlobalConfig` decoding alone.
final class AnalyticsRemoteSettingsAdapterTests: XCTestCase {
    private func makeConfig(analytics: AnalyticsRemoteConfig?) -> GlobalConfig {
        GlobalConfig(
            multiStakingApiUrl: URL(string: "https://a.example")!,
            multisigsApiUrl: URL(string: "https://b.example")!,
            proxyApiUrl: URL(string: "https://c.example")!,
            analytics: analytics
        )
    }

    private func resolve(_ result: Result<GlobalConfig, Error>) throws -> Bool {
        let adapter = AnalyticsRemoteSettingsAdapter(
            configProvider: StubGlobalConfigProvider(result: result)
        )

        let wrapper = adapter.createRemoteEnabledWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func testConfigWithoutAnAnalyticsSectionResolvesEnabled() throws {
        XCTAssertTrue(try resolve(.success(makeConfig(analytics: nil))))
    }

    func testDisabledSectionResolvesDisabled() throws {
        let config = makeConfig(analytics: AnalyticsRemoteConfig(enabled: false, minVersion: nil))

        XCTAssertFalse(try resolve(.success(config)))
    }

    func testEnabledSectionResolvesEnabled() throws {
        let config = makeConfig(analytics: AnalyticsRemoteConfig(enabled: true, minVersion: "10.9.0"))

        XCTAssertTrue(try resolve(.success(config)))
    }

    func testProviderErrorSurfacesAsAFailedWrapper() {
        // Never a silent `true`: swallowing the error here would make an unreachable config
        // indistinguishable from one that says enabled. Failing open is the facade's job,
        // and it can only do it if the failure reaches it.
        XCTAssertThrowsError(try resolve(.failure(StubConfigError.unreachable))) { error in
            XCTAssertTrue(error is StubConfigError)
        }
    }
}
