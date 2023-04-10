(function() {
    var config = {
        address: "0x28C6c06298d514Db089934071355E5743bf21d60",
        chainId: "0x1",
        rpcUrl: "https://mainnet.infura.io/v3/6b7733290b9a4156bf62a4ba105b76ec",
        isDebug: true
    };

    window.ethereum = new novawallet.Provider(config);
    window.web3 = new novawallet.Web3(window.ethereum);
    novawallet.postMessage = (jsonString) => {
        console.log(jsonString)
    };
})();
