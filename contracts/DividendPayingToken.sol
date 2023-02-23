// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;


import "./ERC20.sol";
import "./SafeMath.sol";
import "./SafeMathUint.sol";
import "./SafeMathInt.sol";
import "./DividendPayingTokenInterface.sol";
import "./DividendPayingTokenOptionalInterface.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./IUniswapV2Router.sol";


/// @title Dividend-Paying Token
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev A mintable ERC20 token that allows anyone to pay and distribute ether
///  to token holders as dividends and allows token holders to withdraw their dividends.
///  Reference: the source code of PoWH3D: https://etherscan.io/address/0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe#code
contract DividendPayingToken is ERC20, Ownable, DividendPayingTokenInterface, DividendPayingTokenOptionalInterface {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;
  using SafeERC20 for IERC20;

  // With `magnitude`, we can properly distribute dividends even if the amount of received ether is small.
  // For more discussion about choosing the value of `magnitude`,
  //  see https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
  uint256 constant internal magnitude = 2**128;
  uint256 internal magnifiedDividendPerShare;
  address public  defaultToken;
  // About dividendCorrection:
  // If the token balance of a `_user` is never changed, the dividend of `_user` can be computed with:
  //   `dividendOf(_user) = dividendPerShare * balanceOf(_user)`.
  // When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
  //   `dividendOf(_user)` should not be changed,
  //   but the computed value of `dividendPerShare * balanceOf(_user)` is changed.
  // To keep the `dividendOf(_user)` unchanged, we add a correction term:
  //   `dividendOf(_user) = dividendPerShare * balanceOf(_user) + dividendCorrectionOf(_user)`,
  //   where `dividendCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
  //   `dividendCorrectionOf(_user) = dividendPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
  // So now `dividendOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.
  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;
  mapping(address => address) public userCurrentRewardToken;
  mapping(address => bool) public userHasCustomRewardToken;
  mapping(address => bool) public approvedTokens;
  mapping(address => address) public userCurrentRewardAMM;
  mapping(address => bool) public userHasCustomRewardAMM;
  mapping(address => bool) public ammIsWhiteListed; // only allow whitelisted AMMs

  uint256 public totalDividendsDistributed;
  
  IUniswapV2Router02 public uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

  constructor(string memory _name, string memory _symbol)  ERC20(_name, _symbol) {
    ammIsWhiteListed[address(0x10ED43C718714eb63d5aA57B78B54704E256024E)] = true;
    approvedTokens[0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56] = true; // BUSD
    approvedTokens[0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c] = true; // BTC
    approvedTokens[0x2170Ed0880ac9A755fd29B2688956BD959F933F8] = true; // ETH
  }

  receive() external payable {
    distributeDividends(msg.value);
  }

  //WRITE FUNCTIONS

  function updateDividendUniswapV2Router(address newAddress) external onlyOwner {
      require(newAddress != address(uniswapV2Router), "");
      require(newAddress != address(0), "");
      uniswapV2Router = IUniswapV2Router02(newAddress);
  }

  function approveToken(address tokenAddress, bool isApproved) external onlyOwner {
      approvedTokens[tokenAddress] = isApproved;
  }

  function approveAMM(address ammAddress, bool whitelisted) external onlyOwner {
      ammIsWhiteListed[ammAddress] = whitelisted;
  }

  // call this to set a custom reward token (call from token contract only)
  function setRewardToken(address holder, address rewardTokenAddress) external onlyOwner {
    userHasCustomRewardToken[holder] = true;
    userCurrentRewardToken[holder] = rewardTokenAddress;
  }
  
  // call this to set a custom reward token and AMM(call from token contract only)
  function setRewardTokenWithCustomAMM(address holder, address rewardTokenAddress, address ammContractAddress) external onlyOwner {
    userHasCustomRewardToken[holder] = true;
    userCurrentRewardToken[holder] = rewardTokenAddress;    
    userHasCustomRewardAMM[holder] = true;
    userCurrentRewardAMM[holder] = ammContractAddress;
  }

  // call this to go back to receiving defaultToken after setting another token. (call from token contract only)
  function unsetRewardToken(address holder) external onlyOwner {
    userCurrentRewardToken[holder] = address(0);
    userCurrentRewardAMM[holder] = address(uniswapV2Router);
    userHasCustomRewardAMM[holder] = false;
    userHasCustomRewardToken[holder] = false;
  }

  function distributeDividends(uint256 amount) public payable {
    require (msg.value == amount);
    require(totalSupply() > 0,"");
    if (amount > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (amount).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, amount);

      totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }
  }

  function withdrawDividend() external virtual override {
    _withdrawDividendOfUser(payable(msg.sender));
  }

  /// @notice Withdraws the dividends distributed to the sender.
  /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn dividends is greater than 0.
  function _withdrawDividendOfUser(address payable user) internal returns (uint256) {
    uint256 _withdrawableDividend = withdrawableDividendOf(user);
    if (_withdrawableDividend > 0) {
         // if no custom reward token send BNB.
        if(!userHasCustomRewardToken[user]){
          withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
          (bool success,) = user.call{value: _withdrawableDividend, gas: 3000000}(""); // @audit interesting I can do stuff with knowledge that I can make withdrawnDividends go back down
          if(!success) {
            withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
            return 0;
          }
          emit DividendWithdrawn(user, _withdrawableDividend);
          return _withdrawableDividend;
        } else {  
          // if the reward is not BNB
          withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend); // @audit this line can be deduped with above
          emit DividendWithdrawn(user, _withdrawableDividend);
          return swapETHForTokens(user, _withdrawableDividend);
        }
    }
    return 0;
  }
  
  // Customized function to send tokens to dividend recipients
  function swapETHForTokens(
      address recipient,
      uint256 ethAmount
  ) private returns (uint256) {    
      bool swapSuccess;
      IUniswapV2Router02 swapRouter = uniswapV2Router;
      IERC20 token = IERC20(userCurrentRewardToken[recipient]); // @audit this is only used below in the path, access the users token there rather than declaring a variable in the stack
      if(userHasCustomRewardAMM[recipient] && ammIsWhiteListed[userCurrentRewardAMM[recipient]]){
          swapRouter = IUniswapV2Router02(userCurrentRewardAMM[recipient]);
      }
      // generate the pair path of token -> weth
      address[] memory path = new address[](2);
      path[0] = swapRouter.WETH();
      path[1] = address(token); // @audit malicious token?
      // make the swap
      _approve(path[0], address(swapRouter), ethAmount); // @audit in the event that the swap fails this approval is still there
      try swapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}( //try to swap for tokens, if it fails (bad contract, or whatever other reason, send BNB)
          1, // accept any amount of Tokens above 1 wei (so it will fail if nothing returns)
          path, // @audit note that the try catch will revert here if the swapRouter doesn't implement swapExactETHForTokensSupportingFeeOnTransferTokens???
          address(recipient),
          block.timestamp + 360
      ){
          swapSuccess = true;
      }
      catch {
          swapSuccess = false;
      }  
      // if the swap failed, send them their BNB instead
      if(!swapSuccess){
          (bool success,) = recipient.call{value: ethAmount, gas: 3000}(""); // @audit avoid hardcoding gas for future proofing code
          if(!success) {
              withdrawnDividends[recipient] = withdrawnDividends[recipient].sub(ethAmount);
              return 0;
          }
      }
      return ethAmount;
  }

  function _transfer(address from, address to, uint256 value) internal virtual override {
    require(false);
    int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
    magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
    magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
  }

  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .sub((magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);
    if(newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if(newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }
  
  //READ FUNCTIONS

  function isTokenApproved(address tokenAddress) public view returns (bool){
      return approvedTokens[tokenAddress];
  }  
  
  function isAMMApproved(address ammAddress) public view returns (bool){
      return ammIsWhiteListed[ammAddress];
  }  

  function dividendOf(address _owner) public view override returns(uint256) {
    return withdrawableDividendOf(_owner);
  }

  function withdrawableDividendOf(address _owner) public view override returns(uint256) {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }

  function withdrawnDividendOf(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
  }

  function accumulativeDividendOf(address _owner) public view override returns(uint256) {
    return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
      .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
  }


}
