function injectScript(document, path) {
    // inject our data injector
    const script = document.createElement('script');

    script.src = chrome.runtime.getURL(path);
    console.log(script.src);

    script.onload = function() {
      // remove the injecting tag when loaded
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };

    (document.head || document.documentElement).appendChild(script);
}

injectScript(document, "nova_min.js");
injectScript(document, "metamask_min.js");

window.addEventListener("message", ({ data, source }) => {
  // only allow messages from our window, by the loader
  if (source !== window) {
    return;
  }

  if (data.origin === "dapp-request") {
    browser.runtime.sendMessage({ greeting: "dapp" }).then((response) => {
        console.log("Received response: ", response);
    });

    // window.webkit.messageHandlers.\(name).postMessage(data);
  }
});
