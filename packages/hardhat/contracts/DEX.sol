pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DEX
 * @author Steve P.
 * @notice this is a single token pair reserves DEX, ref: "Scaffold-ETH Challenge 2" as per https://speedrunethereum.com/challenge/token-vendor
 */
contract DEX {
    uint256 public totalLiquidity; //BAL token total liquidity in this contract
    mapping(address => uint256) public liquidity;

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
    event EthToTokenSwap(address swapper, string txDetails, uint256 ethInput, uint256 tokenOutput);
    event TokenToEthSwap(address swapper, string txDetails, uint256 tokensInput, uint256 ethOutput);
    event LiquidityProvided(address liquidityProvider, uint256 tokensInput, uint256 ethInput, uint256 liquidityMinted);
    event LiquidityRemoved(address liquidityRemover, uint256 tokensOutput, uint256 ethOutput, uint256 liquidityWithdrawn);
    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
   

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    

    /**
     * @notice Emitted when liquidity provided to DEX
     */
 

    /**
     * @notice Emitted when liquidity removed from DEX
     */


    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the balance of this DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX: init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), tokens), "DEX: init - transfer did not transact");
        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public view returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput.mul(997);
        uint256 numerator = xInputWithFee.mul(yReserves);
        uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);
        return (numerator / denominator);
    }

    /**
     * @notice returns liquidity for a user
     */
    function getLiquidity(address lp) public view returns(uint256) {
    return liquidity[lp];
  }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        //  require(msg.value > 0, "ethToToken: can't trade 0");
        uint256 ethReserve = address(this).balance.sub(msg.value);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 tokenOutput = price(msg.value, ethReserve, token_reserve);

        //  totalLiquidity = totalLiquidity.sub(tokenOutput); //update totalLiquidity? I guess you don't because even though liquidity is changing... it isn't in a macro-scale? We still have the same amount of liquidity in "total" but just different asset ratios.
        require(token.transfer(msg.sender, tokenOutput), "ethToToken(): reverted swap.");
        emit EthToTokenSwap(msg.sender, "Eth to Balloons", msg.value, tokenOutput);
        return tokenOutput;
        
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     * NOTE: if you try putting in 0 tokens, it will revert either due to erc20, or due to price() returning 0.
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 ethOutput = price(tokenInput, token_reserve, address(this).balance);
        require(token.transferFrom(msg.sender, address(this), tokenInput), "tokenToEth(): reverted swap.");
        (bool sent, ) = msg.sender.call{ value: ethOutput }("");
        require(sent, "tokenToEth: revert in transferring eth to you!");
        emit TokenToEthSwap(msg.sender, "Balloons to ETH", ethOutput, tokenInput);
        return ethOutput;
        
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: Ratio needs to be maintained.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        uint256 ethReserve = address(this).balance.sub(msg.value);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokenDeposit;

        tokenDeposit = ((msg.value.mul(tokenReserve)) / ethReserve).add(1);
        uint256 liquidityMinted = msg.value.mul(totalLiquidity / ethReserve);
        liquidity[msg.sender] = liquidity[msg.sender].add(liquidityMinted);
        totalLiquidity = totalLiquidity.add(liquidityMinted);

        require(token.approve(address(this), (tokenDeposit.add(1)))); // probably a better way to ensure that approve covers the tx amount.
        require(token.transferFrom(msg.sender, address(this), tokenDeposit));
        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenDeposit);
        return tokenDeposit;
        
    }


    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {
        require(liquidity[msg.sender]>= amount, "withdraw: sender does not have enough liquidity to withdraw.");
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethWithdrawn;

        ethWithdrawn = amount.mul(ethReserve)/ totalLiquidity;

        uint256 tokenAmount = amount.mul(tokenReserve) / totalLiquidity;
        liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
        totalLiquidity = totalLiquidity.sub(amount);
        (bool sent, ) = payable(msg.sender).call{ value: ethWithdrawn }("");
        require(sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, tokenAmount));
        emit LiquidityRemoved(msg.sender, amount, ethWithdrawn, tokenAmount);
        return (ethWithdrawn, tokenAmount);
        
    }
}