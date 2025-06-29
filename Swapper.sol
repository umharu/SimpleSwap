// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title IVerifier
 * @dev Interface for external contract verification
 */
interface IVerifier {
    /**
     * @dev Verifies swap parameters on external contract
     * @param swapContract Address of the swap contract
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @param amountA Amount of token A
     * @param amountB Amount of token B
     * @param amountIn Input amount for swap
     * @param author Author identifier
     */
    function verify(
        address swapContract,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 amountIn,
        string calldata author
    ) external;
}

/**
 * @title Swapper
 * @dev Automated Market Maker (AMM) contract implementing Uniswap-like functionality
 * @dev Supports adding/removing liquidity, swapping tokens, and price calculations
 * @dev Uses constant product formula (x * y = k) with 0.3% fee
 */
contract Swapper {
    using SafeMath for uint256;

    // Token addresses
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    // Pool reserves
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    // Fee (0.3%)
    uint256 public constant FEE = 30; // 0.3% = 30 basis points
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    // Events
    event AddLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, address indexed to);

    /**
     * @dev Constructor initializes the Swapper contract with two token addresses
     * @param _tokenA Address of the first token (e.g., Ethereum)
     * @param _tokenB Address of the second token (e.g., Bitcoin)
     * @notice The order of tokens determines the swap direction and price calculations
     */
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
     * @dev Adds liquidity to the pool and mints liquidity tokens
     * @param _tokenA Address of token A (must match contract's tokenA)
     * @param _tokenB Address of token B (must match contract's tokenB)
     * @param amountADesired Desired amount of token A to add
     * @param amountBDesired Desired amount of token B to add
     * @param amountAMin Minimum acceptable amount of token A (slippage protection)
     * @param amountBMin Minimum acceptable amount of token B (slippage protection)
     * @param to Address that will receive the liquidity tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amountA Actual amount of token A added
     * @return amountB Actual amount of token B added
     * @return liquidity Amount of liquidity tokens minted
     * @notice First liquidity provider can add any amounts, subsequent providers must maintain ratio
     * @notice Requires approval of both tokens before calling this function
     */
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(deadline >= block.timestamp, "Expired");
        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "Invalid tokens");
        require(to != address(0), "Invalid recipient");

        // Calculate optimal amounts
        if (totalLiquidity == 0) {
            // First liquidity provider
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            // Calculate based on current ratio
            uint256 amountBOptimal = amountADesired.mul(reserveB).div(reserveA);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = amountBDesired.mul(reserveA).div(reserveB);
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        require(amountA > 0 && amountB > 0, "Insufficient amounts");

        // Transfer tokens
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        // Calculate liquidity
        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA.mul(amountB));
        } else {
            liquidity = min(
                amountA.mul(totalLiquidity).div(reserveA),
                amountB.mul(totalLiquidity).div(reserveB)
            );
        }

        // Update reserves
        reserveA = reserveA.add(amountA);
        reserveB = reserveB.add(amountB);
        totalLiquidity = totalLiquidity.add(liquidity);

        emit AddLiquidity(to, amountA, amountB, liquidity);
    }

    /**
     * @dev Removes liquidity from the pool and returns underlying tokens
     * @param _tokenA Address of token A (must match contract's tokenA)
     * @param _tokenB Address of token B (must match contract's tokenB)
     * @param liquidity Amount of liquidity tokens to burn
     * @param amountAMin Minimum amount of token A to receive (slippage protection)
     * @param amountBMin Minimum amount of token B to receive (slippage protection)
     * @param to Address that will receive the underlying tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amountA Amount of token A received
     * @return amountB Amount of token B received
     * @notice Burns liquidity tokens and returns proportional amounts of underlying tokens
     * @notice The amounts returned are proportional to the liquidity tokens burned
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "Expired");
        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "Invalid tokens");
        require(to != address(0), "Invalid recipient");
        require(liquidity > 0, "Invalid liquidity");

        // Calculate amounts
        amountA = liquidity.mul(reserveA).div(totalLiquidity);
        amountB = liquidity.mul(reserveB).div(totalLiquidity);

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient amounts");

        // Update reserves
        reserveA = reserveA.sub(amountA);
        reserveB = reserveB.sub(amountB);
        totalLiquidity = totalLiquidity.sub(liquidity);

        // Transfer tokens
        require(tokenA.transfer(to, amountA), "Transfer A failed");
        require(tokenB.transfer(to, amountB), "Transfer B failed");

        emit RemoveLiquidity(to, amountA, amountB, liquidity);
    }

    /**
     * @dev Swaps exact input amount of tokens for output tokens
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMin Minimum amount of output tokens to receive (slippage protection)
     * @param path Array of token addresses [inputToken, outputToken]
     * @param to Address that will receive the output tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amounts Array containing [inputAmount, outputAmount]
     * @notice Currently supports only direct swaps (A to B or B to A)
     * @notice Requires approval of input token before calling this function
     * @notice Applies 0.3% fee to the swap
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path.length == 2, "Invalid path");
        require(path[0] == address(tokenA) && path[1] == address(tokenB), "Invalid tokens");
        require(to != address(0), "Invalid recipient");

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = getAmountOut(amountIn, reserveA, reserveB);

        require(amounts[1] >= amountOutMin, "Insufficient output");

        // Transfer tokens
        require(tokenA.transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
        require(tokenB.transfer(to, amounts[1]), "Transfer out failed");

        // Update reserves
        reserveA = reserveA.add(amountIn);
        reserveB = reserveB.sub(amounts[1]);

        emit Swap(msg.sender, amountIn, amounts[1], to);
    }

    /**
     * @dev Gets the current price of tokenA in terms of tokenB
     * @param _tokenA Address of token A (must match contract's tokenA)
     * @param _tokenB Address of token B (must match contract's tokenB)
     * @return price Price of tokenA in terms of tokenB with 18 decimal precision
     * @notice Price is calculated as reserveB / reserveA * 1e18
     * @notice Returns 0 if reserves are insufficient
     */
    function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price) {
        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "Invalid tokens");
        require(reserveB > 0, "Insufficient reserves");
        price = reserveB.mul(1e18).div(reserveA);
    }

    /**
     * @dev Calculates the output amount for a given input using the AMM formula
     * @param amountIn Amount of input tokens
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Expected output amount after applying 0.3% fee
     * @notice Uses constant product formula: (amountIn * (10000 - 30) * reserveOut) / (reserveIn * 10000 + amountIn * (10000 - 30))
     * @notice This is a pure function that doesn't modify state
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn.mul(FEE_DENOMINATOR.sub(FEE));
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
        amountOut = numerator.div(denominator);
    }

    /**
     * @dev Calculates the integer square root using Newton's method
     * @param y Number to calculate square root of
     * @return z Integer square root of y
     * @notice Used for calculating initial liquidity tokens
     * @notice This is an internal pure function
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Returns the smaller of two numbers
     * @param a First number
     * @param b Second number
     * @return The smaller of a and b
     * @notice This is an internal pure function
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the current reserves of both tokens
     * @return reserveA Current reserve of token A
     * @return reserveB Current reserve of token B
     * @notice This is a view function that doesn't modify state
     */
    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    /**
     * @dev Calls the verify function on an external contract
     * @param verifierAddress Address of the external verifier contract
     * @param _tokenA Address of token A
     * @param _tokenB Address of token B
     * @param amountA_ Amount of token A for verification
     * @param amountB_ Amount of token B for verification
     * @param amountIn_ Input amount for verification
     * @param author_ Author identifier string
     * @notice This function allows integration with external verification systems
     * @notice The external contract must implement the IVerifier interface
     */
    function callVerifyOnOtherContract(
        address verifierAddress,
        address _tokenA,
        address _tokenB,
        uint256 amountA_,
        uint256 amountB_,
        uint256 amountIn_,
        string calldata author_
    ) external {
        IVerifier(verifierAddress).verify(
            address(this),
            _tokenA,
            _tokenB,
            amountA_,
            amountB_,
            amountIn_,
            author_
        );
    }
}


    


