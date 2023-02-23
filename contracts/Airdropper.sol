// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Address.sol";
import "./Ownable.sol";

abstract contract Reentrancy {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    constructor () {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}


contract Airdropper is Ownable, Reentrancy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    mapping(address => bool) public isAirdropped;
    address public newToken;

    event Airdropped(
    	uint256 amount,
        address holder
    );

    constructor() {}

    receive() external payable {}

    //WRITE FUNCTIONS OWNER


   function airdrop(address[] calldata holders, uint[] calldata amounts) external onlyOwner {
        require(holders.length == amounts.length, "");
        for(uint256 i = 0; i < holders.length; i++) {
            if (!isAirdropped[holders[i]]){
                require(IERC20(newToken).balanceOf(address(this)) >= amounts[i],"not enough tokens, refill the contract."); // @audit can save a lot of gas using a custom revert
                IERC20(newToken).safeTransfer(payable(holders[i]), amounts[i]); // @audit there could be a blacklisted address that stops this
                isAirdropped[holders[i]] = true;
            }
        }
   }

   function unlockAirdrop(address[] calldata holders) external onlyOwner {
       //manage edge cases
       for(uint256 i = 0; i < holders.length; i++){
           isAirdropped[holders[i]] = false;
       }
   }

   function emergencyWithdraw() public onlyOwner {
       IERC20 token = IERC20(newToken);
       token.transfer(payable(msg.sender), token.balanceOf(address(this)));
   }
}
