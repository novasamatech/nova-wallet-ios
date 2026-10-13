import XCTest
import Operation_iOS
import NovaAuth
@testable import novawallet

private final class AuthConfigProvider: GlobalConfigProviding {
    private let snapshot: GlobalConfigSnapshot = {
        let url = URL(string: "https://first.test")!
        let config = GlobalConfig(multiStakingApiUrl: url, multisigsApiUrl: url, proxyApiUrl: url, infraUrl: url)
        return GlobalConfigSnapshot(config: config, revision: 1)
    }()

    func addSnapshotObserver(_: AnyObject, closure _: @escaping (GlobalConfigSnapshot) -> Void) {}
    func createConfigSnapshotWrapper() -> CompoundOperationWrapper<GlobalConfigSnapshot> { .createWithResult(snapshot) }
    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> { .createWithResult(snapshot.config) }
}

final class NovaAuthFacadeTests: XCTestCase {
}
