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


contract Presale is Ownable, Reentrancy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    mapping(address => uint256) public boughtAmount;
    uint256 public cap;
    address public token;
    uint256 public exchangeRatio;
    bool public airDropActive = true;

    constructor() {}

    receive() external payable {
        require(airDropActive,"presale closed");
        buyPresale(msg.value);
    }

    //WRITE FUNCTIONS OWNER

    /*
    @dev simple presale in which we set a multiplier(exchangeRatio) and send out msg.value*exchangRatio until the tokens are available
    The users are capped as well through `cap`
    */
    function buyPresale(uint256 value) public {
        require(value == msg.value, "");
        require(boughtAmount[msg.sender].add(value) <= cap, "");
        uint256 amount = value.mul(exchangeRatio);
        require(amount <= IERC20(token).balanceOf(address(this)),"");
        IERC20(token).transfer(msg.sender, value);
        closeAirdrop();
   }

   function closeAirdrop() public {
       //manage edge cases
        if (IERC20(token).balanceOf(address(this)) ==  0){
            airDropActive = false;
        }
   }

   function emergencyWithdraw() public onlyOwner {
       IERC20(token).transfer(payable(msg.sender), IERC20(token).balanceOf(address(this)));
       closeAirdrop();
   }

   function reOpen() public onlyOwner {
       airDropActive=true;
   }
}
