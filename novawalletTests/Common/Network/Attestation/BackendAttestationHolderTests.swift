import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import NovaAnalytics
import NovaAppAttest
import Operation_iOS

final class BackendAttestationHolderTests: XCTestCase {
    private let infraURL = URL(string: "https://infra.test/")!
    private let appIdentity = AppAttestAppIdentity(
        appId: "PREFIX.io.novafoundation.novawallet.dev",
        environment: "development"
    )

    func testAnalyticsAndBittensorShareOneProviderInstance() throws {
        let configProvider = makeConfigProvider()
        let appAttest = makeAppAttest()

        let holder = BackendAttestationHolder(
            configProvider: configProvider,
            appAttest: appAttest,
            appIdentity: appIdentity,
            settingsManager: InMemorySettingsManager(),
            operationQueue: OperationQueue()
        )

        let analyticsAttestation = try fetch(AnalyticsAttestationAdapter(holder: holder).createAttestationWrapper())

        let bittensorEndpoint = try fetch(
            BittensorAttestationHolder(
                attestationHolder: holder,
                appAttest: appAttest,
                appIdentity: appIdentity,
                isUnitTesting: false
            ).createEndpointWrapper()
        )

        XCTAssertTrue(analyticsAttestation.provider === bittensorEndpoint.provider)
        XCTAssertEqual(analyticsAttestation.gatewayURL, infraURL)
        XCTAssertEqual(bittensorEndpoint.gatewayURL, infraURL)
        verify(configProvider, times(1)).createConfigWrapper()
    }

    private func makeAppAttest() -> MockAppAttestServiceProtocol {
        let appAttest = MockAppAttestServiceProtocol()

        stub(appAttest) { stub in
            when(stub.isSupported.get).thenReturn(true)
        }

        return appAttest
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

    private func fetch<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
