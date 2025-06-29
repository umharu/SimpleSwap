# Swapper - Simple AMM Contract

A simplified Automated Market Maker (AMM) smart contract that replicates Uniswap functionality. This contract allows users to add/remove liquidity, swap tokens, and get price information using the constant product formula.

## 🎯 Features

- **Add Liquidity**: Provide liquidity to token pairs
- **Remove Liquidity**: Withdraw liquidity and receive tokens back
- **Swap Tokens**: Exchange one token for another
- **Get Price**: Query current token prices
- **Calculate Amount Out**: Determine output amount for swaps

## 📋 Requirements

- Solidity ^0.8.30
- OpenZeppelin Contracts (IERC20, SafeMath)
- Any ERC-20 compatible tokens

## 🚀 Quick Start

### 1. Deploy the Contract

```solidity
// Deploy with two token addresses
Swapper swapper = new Swapper(tokenAAddress, tokenBAddress);
```

### 2. Add Initial Liquidity

```solidity
// First liquidity provider sets the initial price
swapper.addLiquidity(
    tokenAAddress,
    tokenBAddress,
    1000e18,  // 1000 tokens of A
    1000e18,  // 1000 tokens of B
    0,        // min A
    0,        // min B
    msg.sender,
    block.timestamp + 3600
);
```

### 3. Swap Tokens

```solidity
// Swap 100 tokens of A for B
address[] memory path = [tokenAAddress, tokenBAddress];
swapper.swapExactTokensForTokens(
    100e18,   // amount in
    0,        // min amount out
    path,
    msg.sender,
    block.timestamp + 3600
);
```

## 📍 Deployed Contracts

### Sepolia Testnet
- **Token A (Ethereum)**: [`0x1B7C13693dA78AdDBd906F8bD739E1Ed7dB8d363`](https://sepolia.etherscan.io/address/0x1B7C13693dA78AdDBd906F8bD739E1Ed7dB8d363)
- **Token B (Bitcoin)**: [`0xf07eF8ab66E2E5F7A770dF831944f9a10EF61B29`](https://sepolia.etherscan.io/address/0xf07eF8ab66E2E5F7A770dF831944f9a10EF61B29)
- **Swapper Contract**: [`0x48c6C1Ef0fCb02398C4E10775942b3edb4efa475`](https://sepolia.etherscan.io/address/0x48c6C1Ef0fCb02398C4E10775942b3edb4efa475)
- **Contract Verifier**: [`0x9f8F02DAB384DDdf1591C3366069Da3Fb0018220`](https://sepolia.etherscan.io/tx/0xe27ec2456e607a550690afa23c8c79e88f9ff67662774de0536ba5a2e3681889)
Authors: 97 "Maximiliano"


## 📖 Function Reference

### Add Liquidity
```solidity
function addLiquidity(
    address _tokenA,
    address _tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) external returns (uint256 amountA, uint256 amountB, uint256 liquidity)
```

**Purpose**: Add liquidity to the pool and receive liquidity tokens.

**Parameters**:
- `_tokenA`, `_tokenB`: Token addresses
- `amountADesired`, `amountBDesired`: Desired amounts to add
- `amountAMin`, `amountBMin`: Minimum acceptable amounts (slippage protection)
- `to`: Recipient of liquidity tokens
- `deadline`: Transaction expiration timestamp

**Returns**: Actual amounts added and liquidity tokens minted

### Remove Liquidity
```solidity
function removeLiquidity(
    address _tokenA,
    address _tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) external returns (uint256 amountA, uint256 amountB)
```

**Purpose**: Remove liquidity and receive underlying tokens back.

**Parameters**:
- `_tokenA`, `_tokenB`: Token addresses
- `liquidity`: Amount of liquidity tokens to burn
- `amountAMin`, `amountBMin`: Minimum amounts to receive
- `to`: Recipient of withdrawn tokens
- `deadline`: Transaction expiration timestamp

**Returns**: Amounts of tokens A and B received

### Swap Tokens
```solidity
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts)
```

**Purpose**: Swap exact input amount for output tokens.

**Parameters**:
- `amountIn`: Input token amount
- `amountOutMin`: Minimum output amount (slippage protection)
- `path`: Array of token addresses [input, output]
- `to`: Recipient of output tokens
- `deadline`: Transaction expiration timestamp

**Returns**: Array with input and output amounts

### Get Price
```solidity
function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price)
```

**Purpose**: Get current price of tokenA in terms of tokenB.

**Returns**: Price with 18 decimal precision

### Calculate Amount Out
```solidity
function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
) public pure returns (uint256 amountOut)
```

**Purpose**: Calculate output amount for a given input using AMM formula.

**Returns**: Expected output amount

## 🔧 Technical Details

### AMM Mechanics
- **Constant Product Formula**: `x * y = k`
- **Fee Structure**: 0.3% fee on all swaps
- **Price Discovery**: Automatic based on supply and demand
- **Slippage Protection**: Minimum amount parameters

### Security Features
- **SafeMath**: Overflow/underflow protection
- **Deadline Checks**: Prevents stale transactions
- **Input Validation**: Comprehensive parameter checking
- **Slippage Protection**: Minimum amount requirements

## 👨‍💻 Author

**Maximiliano** 

## ⚠️ Disclaimer

This contract is for educational and development purposes. Use at your own risk in production environments. Always conduct thorough testing and security audits before deployment.
