// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;


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
    IERC20 public newToken = IERC20(0xb7486718ea21C79BBd894126f79F504fd3625f68);

    constructor() {}

    receive() external payable {}

    //WRITE FUNCTIONS OWNER


   function airdrop(address[] calldata holders, uint[] calldata amounts) external onlyOwner {
        require(holders.length == amounts.length, "");
        for(uint256 i = 0; i < holders.length; i++) {
            if (!isAirdropped[holders[i]]){
                require(newToken.balanceOf(address(this)) >= amounts[i],"not enough tokens, refill the contract.");
                newToken.safeTransfer(payable(holders[i]), amounts[i]);
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
       newToken.transfer(payable(msg.sender), newToken.balanceOf(address(this)));
   }
}
