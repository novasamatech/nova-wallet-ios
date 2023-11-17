import XCTest
@testable import novawallet
import SoraKeystore
import Cuckoo
import BigInt

final class SwapsValidationTests: XCTestCase {
    private func amountInPlank(_ amount: Decimal, _ chainAsset: ChainAsset) -> BigUInt {
        amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 0
    }
    
    func testCalculatedFeeWithoutED() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 3, addressPrefix: 42)
        let utilityChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 0 })!)
        let payChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 2 })!)
        let feeChainAsset = payChainAsset
        let accountId = try WestendStub.address.toAccountId()
        
        let freeBalance = amountInPlank(50, payChainAsset)
        let payAssetBalance = AssetBalance(chainAssetId: payChainAsset.chainAssetId,
                                           accountId: accountId,
                                           freeInPlank: freeBalance,
                                           reservedInPlank: 0,
                                           frozenInPlank: 0,
                                           blocked: false)
        let existentialDeposit = amountInPlank(1, utilityChainAsset)
        let fee = amountInPlank(0.1, payChainAsset)
        let existentialDepositInFeeToken = amountInPlank(0.01, payChainAsset)
        
        let swapMax = SwapMaxModel(
            payChainAsset: payChainAsset,
            feeChainAsset: feeChainAsset,
            balance: payAssetBalance,
            feeModel: .init(
                totalFee: .init(
                    targetAmount: fee + existentialDepositInFeeToken,
                    nativeAmount: (fee + existentialDeposit) / 100
                ),
                networkFee: .init(
                    targetAmount: fee,
                    nativeAmount: fee / 100
                )
            ),
            payAssetExistense: nil,
            receiveAssetExistense: nil,
            accountInfo: nil
        )
        
        let result = swapMax.calculate()
        
        XCTAssertEqual(result, 49.89)
       
    }
    
    func testCalculatedFeeWithED() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 3, addressPrefix: 42)
        let utilityChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 0 })!)
        let payChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 2 })!)
        let feeChainAsset = utilityChainAsset
        let accountId = try WestendStub.address.toAccountId()
        
        let freeBalance = amountInPlank(50, payChainAsset)
        let payAssetBalance = AssetBalance(chainAssetId: payChainAsset.chainAssetId,
                                           accountId: accountId,
                                           freeInPlank: freeBalance,
                                           reservedInPlank: 0,
                                           frozenInPlank: 0,
                                           blocked: false)
        
        let fee = amountInPlank(0.1, payChainAsset)
        
        let params = SwapMaxModel(
            payChainAsset: payChainAsset,
            feeChainAsset: feeChainAsset,
            balance: payAssetBalance,
            feeModel: .init(
                totalFee: .init(
                    targetAmount: fee,
                    nativeAmount: fee
                ),
                networkFee: .init(
                    targetAmount: fee,
                    nativeAmount: fee
                )
            ),
            payAssetExistense: nil,
            receiveAssetExistense: nil,
            accountInfo: nil
        )
        
        let result = params.calculate()
        
        XCTAssertEqual(result, 50)
       
    }
}
