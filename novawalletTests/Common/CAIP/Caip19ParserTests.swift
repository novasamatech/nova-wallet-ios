import XCTest
@testable import novawallet
import SubstrateSdk

class Caip19ParserTests: XCTestCase {
    func testDot() {
        let tokenRaw = KnownToken.polkadot
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.knownChain, .polkadot(genesisHash: "411f057b9107718c9624d6aa4a3f23c1"))
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 2086))
    }

    func testEther() {
        let tokenRaw = KnownToken.ether
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.knownChain, .eip155(id: 1))
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 60))
    }

    func testBitcoin() {
        let tokenRaw = KnownToken.bitcoin
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "bip122")
        XCTAssertEqual(parsedToken!.chainId.reference, "000000000019d6689c085ae165831e93")
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 0))
    }

    func testAtom() {
        let tokenRaw = KnownToken.atom
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "cosmos")
        XCTAssertEqual(parsedToken!.chainId.reference, "cosmoshub-3")
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 118))
    }

    func testLitecoin() {
        let tokenRaw = KnownToken.litecoin
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "bip122")
        XCTAssertEqual(parsedToken!.chainId.reference, "12a765e31ffd4059bada1e25190f6e98")
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 2))
    }

    func testBinance() {
        let tokenRaw = KnownToken.binance
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "cosmos")
        XCTAssertEqual(parsedToken!.chainId.reference, "Binance-Chain-Tigris")
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 714))
    }

    func testIOV() {
        let tokenRaw = KnownToken.iov
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "cosmos")
        XCTAssertEqual(parsedToken!.chainId.reference, "iov-mainnet")
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 234))
    }

    func testLisk() {
        let tokenRaw = KnownToken.lisk
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "lip9")
        XCTAssertEqual(parsedToken!.chainId.reference, "9ee11e9df416b18b")
        XCTAssertEqual(parsedToken!.knownToken, .slip44(coin: 134))
    }

    func testDAI() {
        let tokenRaw = KnownToken.dai
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.knownChain, .eip155(id: 1))
        XCTAssertEqual(parsedToken!.knownToken, .erc20(contract: "0x6b175474e89094c44da98b954eedeac495271d0f"))
    }

    func testCryptoKitties() {
        let collectionRaw = KnownToken.cryptoKittiesCollection
        let collectableRaw = KnownToken.cryptoKittiesCollectible
        let parsedCollectionToken = try? Caip19.AssetId(raw: collectionRaw)
        let parsedCollectableToken = try? Caip19.AssetId(raw: collectableRaw)
        let expectedBlockchain = Caip2.RegisteredChain.eip155(id: 1)
        let expectedToken = Caip19.RegisteredToken.erc721(contract: "0x06012c8cf97BEaD5deAe237070F9587f8E7A266d")
        XCTAssertNotNil(parsedCollectionToken)
        XCTAssertNotNil(parsedCollectableToken)
        XCTAssertEqual(parsedCollectionToken!.chainId.knownChain, expectedBlockchain)
        XCTAssertEqual(parsedCollectableToken!.chainId.knownChain, expectedBlockchain)
        XCTAssertEqual(parsedCollectionToken!.knownToken, expectedToken)
        XCTAssertEqual(parsedCollectableToken!.knownToken, expectedToken)
        XCTAssertEqual(parsedCollectionToken!.tokenId, nil)
        XCTAssertEqual(parsedCollectableToken!.tokenId, "771769")
    }

    func testHedera() {
        let tokenRaw = KnownToken.hedera
        let parsedToken = try? Caip19.AssetId(raw: tokenRaw)
        XCTAssertNotNil(parsedToken)
        XCTAssertEqual(parsedToken!.chainId.namespace, "hedera")
        XCTAssertEqual(parsedToken!.chainId.reference, "mainnet")
        XCTAssertEqual(parsedToken!.assetNamespace, "nft")
        XCTAssertEqual(parsedToken!.assetReference, "0.0.55492")
        XCTAssertEqual(parsedToken!.tokenId, "12")
    }

    func testWrongChain() {
        let wrongChainString = "po:411f057b9107718c9624d6aa4a3f23c1/slip44:2086"

        XCTAssertThrowsError(try Caip19.AssetId(raw: wrongChainString)) { error in
            XCTAssertEqual(error as? Caip2.ParseError, .invalidNamespace(.invalidLength(expected: 3 ... 8, was: 2)))
        }
    }

    func testWrongAsset() {
        let wrongAssetString = "polkadot:411f057b9107718c9624d6aa4a3f23c1/s:2086"

        XCTAssertThrowsError(try Caip19.AssetId(raw: wrongAssetString)) { error in
            XCTAssertEqual(error as? Caip19.ParseError, .invalidAssetNamespace(.invalidLength(expected: 3 ... 8, was: 1)))
        }
    }
}

private enum KnownToken {
    static let polkadot = "polkadot:411f057b9107718c9624d6aa4a3f23c1/slip44:2086"
    static let ether = "eip155:1/slip44:60"
    static let bitcoin = "bip122:000000000019d6689c085ae165831e93/slip44:0"
    static let atom = "cosmos:cosmoshub-3/slip44:118"
    static let litecoin = "bip122:12a765e31ffd4059bada1e25190f6e98/slip44:2"
    static let binance = "cosmos:Binance-Chain-Tigris/slip44:714"
    static let iov = "cosmos:iov-mainnet/slip44:234"
    static let lisk = "lip9:9ee11e9df416b18b/slip44:134"
    static let dai = "eip155:1/erc20:0x6b175474e89094c44da98b954eedeac495271d0f"
    static let cryptoKittiesCollection = "eip155:1/erc721:0x06012c8cf97BEaD5deAe237070F9587f8E7A266d"
    static let cryptoKittiesCollectible = "eip155:1/erc721:0x06012c8cf97BEaD5deAe237070F9587f8E7A266d/771769"
    // Edition 12 of 50: First-Generation Hedera Robot VENOM EDITION
    static let hedera = "hedera:mainnet/nft:0.0.55492/12"
}
