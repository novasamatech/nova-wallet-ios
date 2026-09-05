import XCTest
import Operation_iOS
import Keystore_iOS
@testable import NovaAnalytics

private final class RemoteSettingsStub: AnalyticsRemoteSettings {
    var result: Result<Bool, Error> = .success(true)

    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool> {
        let result = result

        return CompoundOperationWrapper(targetOperation: ClosureOperation { try result.get() })
    }
}

final class AnalyticsConfigurationTests: XCTestCase {
    private func makeConfiguration(
        directory: URL,
        remoteSettings: AnalyticsRemoteSettings
    ) -> AnalyticsConfiguration {
        AnalyticsConfiguration(
            gatewayURL: URL(string: "https://gateway.example/")!,
            appVersion: "10.9.0",
            storeDirectory: directory,
            isReleaseBuild: false,
            isFirstLaunch: { false },
            settingsManager: InMemorySettingsManager(),
            remoteSettings: remoteSettings,
            logger: SilentLogger(),
            operationQueue: OperationQueue(),
            analyticsOperationQueue: OperationQueue()
        )
    }

    func testFacadeBuildsFromConfigurationAlone() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let facade = AnalyticsServiceFacade(
            configuration: makeConfiguration(directory: directory, remoteSettings: RemoteSettingsStub())
        )

        XCTAssertFalse(facade.consent.isEnabled)
    }

    func testAppVersionComesFromConfigurationNotTheBundle() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = makeConfiguration(directory: directory, remoteSettings: RemoteSettingsStub())

        XCTAssertEqual(configuration.appVersion, "10.9.0")
        XCTAssertNotEqual(configuration.appVersion, "")
    }
}
