How to add the "RelaxCoin (R2R)" local network to MetaMask

Overview

This folder contains a JSON descriptor and quick JS snippets you can run in a browser console (with MetaMask available) to add the local Hardhat network and register the R2R token.

Files

- relaxcoin-network.json — network metadata for RelaxCoin Local

Quick steps (UI)

1. Open MetaMask → Networks → Add a network.
2. Set:
   - Network name: RelaxCoin Local
   - RPC URL: http://127.0.0.1:8545
  - Chain ID: 271828
  - Currency symbol: R2R
3. Save. Then open the network and add a custom token by pasting the token address below.

-Token info (for Add Token):
- Token Contract Address: 0x4A679253410272dd5232B3Ff7cF5dbB88f295319
- Token Symbol: R2R
- Decimals: 18

Programmatic method (run in browser console)

If you have MetaMask installed and the page exposes `window.ethereum`, you can run these snippets in the browser console to prompt MetaMask to add the network and the token.

1) Add the network:

```javascript
(async () => {
  if (!window.ethereum) return console.error('MetaMask not detected');
  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: '0x425d4', // 271828
        chainName: 'RelaxCoin Local',
        nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
        rpcUrls: ['http://127.0.0.1:8545'],
        blockExplorerUrls: []
      }]
    });
    console.log('Network add requested');
  } catch (err) {
    console.error('Network add failed', err);
  }
})();
```

2) Add the token to MetaMask (watchAsset):

```javascript
(async () => {
  if (!window.ethereum) return console.error('MetaMask not detected');
  try {
    const wasAdded = await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: '0x610178dA211FEF7D417bC0e6FeD39F05609AD788',
          symbol: 'R2R',
          decimals: 18,
          image: ''
        }
      }
    });
    console.log('Token add requested:', wasAdded);
  } catch (err) {
    console.error('Token add failed', err);
  }
})();
```

Notes

- The JS snippets only prompt MetaMask; the user must confirm the action in the MetaMask popup.
- Make sure your local Hardhat node is running (`npx hardhat node`) and listening on `http://127.0.0.1:8545`.
- If you changed the deployed token address, update `relaxcoin-network.json` and the snippets with the correct contract address.
