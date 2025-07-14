import XCTest
@testable import novawallet
import SubstrateSdk

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
        
        let substrateChain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0, // Polkadot chain
            assetPresicion: 12,
            hasStaking: false,
            hasCrowdloans: false
        )
        
        let chains = [ethereumChain, substrateChain]
        
        // When
        let resolvedChain = try resolver.resolveChainForBytesSigning(
            for: ethereumAddress,
            wallet: wallet,
            chains: chains
        )
        
        // Then
        XCTAssertTrue(resolvedChain.isEthereumBased, "Should resolve to an Ethereum-based chain")
        XCTAssertEqual(resolvedChain.chainId, ethereumChain.chainId, "Should resolve to the correct Ethereum chain")
    }
    
    func testSubstrateAddressChainResolution() throws {
        // Given
        let resolver = DAppSignBytesChainResolver()
        let substrateAddress = "3rBVRJQeQzmvsVH8QvwJafGVdRtHLTFTUdMRoyTmggnx6Qqh"
        
        let accountId = try substrateAddress.toAccountId()
        
        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test Wallet",
            substrateAccountId: accountId,
            substrateCryptoType: 0,
            substratePublicKey: accountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: .secrets,
            multisig: nil
        )
        
        let substrateChain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0, // Polkadot chain
            assetPresicion: 12,
            hasStaking: false,
            hasCrowdloans: false
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
