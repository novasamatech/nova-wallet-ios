import XCTest
@testable import novawallet
import NovaCrypto

class DAppBrowserSigningChainResolverTests: XCTestCase {
    func testEthereumAddressChainResolution() throws {
        // Given
        let resolver = DAppSignBytesChainResolver()
        let ethereumAddress = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test Wallet",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: try Data(hexString: ethereumAddress),
            ethereumPublicKey: Data(repeating: 1, count: 64),
            chainAccounts: [],
            type: .secrets,
            multisig: nil
        )

        let ethereumChain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 1, // Ethereum chain
            assetPresicion: 18,
            hasStaking: false,
            hasCrowdloans: false
        )

        // Add ethereumBased option to make it an Ethereum chain
        let ethereumChainWithOption = ChainModel(
            chainId: ethereumChain.chainId,
            parentId: ethereumChain.parentId,
            name: ethereumChain.name,
            assets: ethereumChain.assets,
            nodes: ethereumChain.nodes,
            nodeSwitchStrategy: ethereumChain.nodeSwitchStrategy,
            addressPrefix: ethereumChain.addressPrefix,
            legacyAddressPrefix: ethereumChain.legacyAddressPrefix,
            types: ethereumChain.types,
            icon: ethereumChain.icon,
            options: [.ethereumBased],
            externalApis: ethereumChain.externalApis,
            explorers: ethereumChain.explorers,
            order: ethereumChain.order,
            additional: ethereumChain.additional,
            syncMode: ethereumChain.syncMode,
            source: ethereumChain.source,
            connectionMode: ethereumChain.connectionMode,
            displayPriority: nil
        )

        let substrateChain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0, // Polkadot chain
            assetPresicion: 12,
            hasStaking: false,
            hasCrowdloans: false
        )

        let chains = [ethereumChainWithOption, substrateChain]

        // When
        let resolvedChain = try resolver.resolveChainForBytesSigning(
            for: ethereumAddress,
            wallet: wallet,
            chains: chains
        )

        // Then
        XCTAssertTrue(resolvedChain.isEthereumBased, "Should resolve to an Ethereum-based chain")
        XCTAssertEqual(resolvedChain.chainId, ethereumChainWithOption.chainId, "Should resolve to the correct Ethereum chain")
    }

    func testSubstrateAddressChainResolution() throws {
        // Given
        let resolver = DAppSignBytesChainResolver()
        let substrateAddress = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"

        let accountId = try substrateAddress.toAccountId()
        let cryptoType: UInt8 = 0 // sr25519

        // Get the address prefix from the test address
        let addressPrefix = try SS58AddressFactory().type(fromAddress: substrateAddress).uint16Value

        let substrateChain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: ChainModel.AddressPrefix(addressPrefix), // Use the actual address prefix
            assetPresicion: 12,
            hasStaking: false,
            hasCrowdloans: false
        )

        // Add a chain account for the test chain
        let chainAccount = ChainAccountModel(
            chainId: substrateChain.chainId,
            accountId: accountId,
            publicKey: accountId,
            cryptoType: cryptoType,
            proxy: nil,
            multisig: nil
        )

        // Test with both chain account and root substrate fields
        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test Wallet",
            substrateAccountId: accountId,
            substrateCryptoType: cryptoType,
            substratePublicKey: accountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccount],
            type: .secrets,
            multisig: nil
        )

        let chains = [substrateChain]

        // When
        let resolvedChain = try resolver.resolveChainForBytesSigning(
            for: substrateAddress,
            wallet: wallet,
            chains: chains
        )

        // Then
        XCTAssertFalse(resolvedChain.isEthereumBased, "Should resolve to a Substrate-based chain")
        XCTAssertEqual(resolvedChain.chainId, substrateChain.chainId, "Should resolve to the correct Substrate chain")
    }
}
