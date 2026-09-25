import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import NovaAppAttest
import Operation_iOS

final class BittensorAttestationHolderTests: XCTestCase {
    private let infraURL = URL(string: "https://infra.test/")!

    func testUnitTestProcessFailsUnsupportedDeviceWithoutFetchingTheConfig() {
        let configProvider = makeConfigProvider()
        let holder = makeHolder(configProvider: configProvider, isUnitTesting: true)

        let wrapper = holder.createContextWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            guard case .unsupportedDevice = error as? BittensorApiError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        verify(configProvider, never()).createConfigWrapper()
    }

    func testProviderIsBuiltOnceOnTheInfraUrl() throws {
        let configProvider = makeConfigProvider()
        let holder = makeHolder(configProvider: configProvider, isUnitTesting: false)

        let firstContext = try fetch(holder.createContextWrapper())
        let secondContext = try fetch(holder.createContextWrapper())

        XCTAssertEqual(firstContext.baseURL, infraURL)
        XCTAssertTrue(firstContext.provider === secondContext.provider)
        verify(configProvider, times(1)).createConfigWrapper()
    }

    private func makeHolder(
        configProvider: MockGlobalConfigProviding,
        isUnitTesting: Bool
    ) -> BittensorAttestationHolder {
        let appAttest = MockAppAttestServiceProtocol()

        stub(appAttest) { stub in
            when(stub.isSupported.get).thenReturn(true)
        }

        return BittensorAttestationHolder(
            configProvider: configProvider,
            appAttest: appAttest,
            appIdentity: AppAttestAppIdentity(appId: "PREFIX.io.novafoundation.novawallet.dev", environment: "development"),
            isUnitTesting: isUnitTesting,
            settingsManager: InMemorySettingsManager(),
            operationQueue: OperationQueue()
        )
    }

    private func makeConfigProvider() -> MockGlobalConfigProviding {
        let configProvider = MockGlobalConfigProviding()
        let config = GlobalConfig(
            multiStakingApiUrl: URL(string: "https://multistaking.test")!,
            multisigsApiUrl: URL(string: "https://multisigs.test")!,
            proxyApiUrl: URL(string: "https://proxy.test")!,
            infraUrl: infraURL
        )

        stub(configProvider) { stub in
            when(stub.createConfigWrapper()).then {
                CompoundOperationWrapper.createWithResult(config)
            }
        }

        return configProvider
    }

    private func fetch(
        _ wrapper: CompoundOperationWrapper<BittensorAttestationContext>
    ) throws -> BittensorAttestationContext {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
