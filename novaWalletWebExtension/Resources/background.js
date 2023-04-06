browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log("Received request: ", request);

    if (request.greeting === "dapp")
        sendResponse({ farewell: "goodbye dapp" });
});
