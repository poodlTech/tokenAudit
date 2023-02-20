# Token token contracts folder

## Testnet

Contracts for bridges migration to new token

## Mainnet

Contracts for Mainnet

## Token Contract structure

### The code is splitted in 18 files

* 15 files are open source contracts to be implemented in order to respect the ERC20 Ethereum standard/BEP20 BSC standard, together with uniswap contracts, Ownable contracts, and the dividend paying token from Roger Wu(https://github.com/roger-wu)
* 3 files are customized Token.sol DividendPayingToken.sol and Airdropper.sol

## Token Customized files

### Token Token.sol

This is the main contract with the token. The contract also deploy the dividend tracker, a second ERC20 that will be minted and burnt everytime the parent token is transferred so to keep the token and the dividend tracker balances always at a 1:1 ratio for each wallet - unless a wallet is excluded from dividends.
The token is also the owner of the tracker token, which means most of the calls have to be performed directly from the token contract.
All the write functions come with a onlyOwner modifier besides the functions in which the user can change their reward token or claim their dividends

### Token DividendPayingToken.sol

This is implementation of the dividend tracker then inherited by the DividendTracker contract in Token.sol. It also uses the library IterableMapping.sol to keep track of the dividends.

### Token Airdropper.sol

Since this token is a migration of the existing Bridges token, there will be a 1:1 airdrop of the new token. The reason why of this contract is to avoid forcing the users to do a manual migration that would take a long time. Also the function to do the airdrop need to be called manually with 2 arrays (accounts and amounts). Given some holders had their tokens staked or in the liquidity when the snapshot was taken we need to do it manually this way, as we can't read directly the bridges balance and airdrop it for these users.

## Overview

The token is a dividend paying token with the possibility to select your reward token, and the AMM where to get it from. Both tokens and AMMs need to be approved by the team. The default is the native coin of the chain. The system work with 2 tokens, the main token that can be traded and a dividend tracker token. Every time a transfer is performed the dividend tracker contract mint and burn the tracker token so to keep the balances at a 1:1 ration with the main token. The dividend tracker token can not be transfered manually by the user.
The fees are applied only on buy and sells and there is an automatedMarketMakerPaird mapping to keep track of it. Wallet to wallet transfer as excluded from fees. The fees are broken down into liquidity fees for swap and liquify which will send the LP tokens back to the marketing wallet, marketing fee to feed the marketing wallet and rewards fees for the dividends. The fees for the dividends collected in the native coin are sent to the tracker contract, which will then do the math to update the dividends owed to each user.
The users will then be able to call the claim function with 2 possible scenarios:
* if they did not select any specific reward token then they will get the amount of native coin they are owed
* if they picked a reward token then their portion of the dividends will be swapped back to the selected tokens and then sent.
The distribution of the dividends is not automated to keep the token gas efficient.
Fees are then split into buy and sell fees with a `sellTopUp` value. If this value is set to 0 then the fees are the same otherwise we can add more % on the sell side to run marketing events and allow for flexibility. The fees are capped to 15% max and they can not be set higher.
