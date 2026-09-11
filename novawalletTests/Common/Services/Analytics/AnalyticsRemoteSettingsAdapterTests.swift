import XCTest
import Operation_iOS
@testable import novawallet

private enum StubConfigError: Error {
    case cachedConfigRequested
}

private final class StubGlobalConfigProvider: GlobalConfigProviding {
    private let analytics: AnalyticsRemoteConfig?

    init(analytics: AnalyticsRemoteConfig?) {
        self.analytics = analytics
    }

    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
        .createWithError(StubConfigError.cachedConfigRequested)
    }

    func createFreshConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
        let config = GlobalConfig(multiStakingApiUrl: URL(string: "https://a.example")!, multisigsApiUrl: URL(string: "https://b.example")!, proxyApiUrl: URL(string: "https://c.example")!, analytics: analytics)
        return CompoundOperationWrapper(targetOperation: ClosureOperation { config })
    }
}

final class AnalyticsRemoteSettingsAdapterTests: XCTestCase {
    func testDisabledSectionResolvesDisabled() throws {
        let provider = StubGlobalConfigProvider(analytics: AnalyticsRemoteConfig(enabled: false, minVersion: nil))

        XCTAssertFalse(try resolveRemoteEnabled(with: provider))
    }

    func testTheAdapterAsksForAFreshConfigRatherThanTheCachedOne() throws {
        XCTAssertTrue(try resolveRemoteEnabled(with: StubGlobalConfigProvider(analytics: nil)))
    }

    private func resolveRemoteEnabled(with provider: StubGlobalConfigProvider) throws -> Bool {
        let wrapper = AnalyticsRemoteSettingsAdapter(configProvider: provider).createRemoteEnabledWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
