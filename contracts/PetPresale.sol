// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./SafeERC20.sol";


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract PetPreSale is Ownable {

    using SafeERC20 for IERC20;

    // address of admin
    IERC20 public token;
    // token price variable
    uint256 public tokenprice;
    // count of token sold vaariable
    uint256 public totalsold; 
    //whitelist
    mapping(address => bool) public whitelist;
    uint256 public lowCap; 
    uint256 public highCap; 
    address public _marketingWalletAddress = 0x5C9D790F7d38c97b6F78a8ad173de262e06f0A37; 
    bool public status = true;

    struct UserInfo {
        uint256 amountMatic;
        uint256 amountToken;
    }
    mapping (address => UserInfo) public userInfo; // Info of each user.
    event Buy(uint256 tokenAmount, uint256 maticAmount, address buyer);
   
    // constructor 
    constructor(address _tokenaddress, uint256 _tokenvalue, uint _lowCap, uint _highCap){
        tokenprice = _tokenvalue;
        token  = IERC20(_tokenaddress);
        lowCap = _lowCap * (10**18);
        highCap = _highCap* (10**18);
    }
    receive() external payable{
        require(status, "presale ended");
        buyPreSale();
    }
    function whitelistWallets(address[] calldata accounts, bool excluded) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = excluded;
        }
    }

    // buyTokens function
    function buyPreSale() public payable{
        require(msg.value >= 0, "no value attached");
        UserInfo storage user = userInfo[msg.sender];
        uint256 boughtSoFar = user.amountToken;
        uint256 sold = msg.value*tokenprice/1000;

        // check if the contract has the tokens or not
        require(token.balanceOf(address(this)) >= sold,'the smart contract dont hold the enough tokens');
        require(whitelist[msg.sender], "address not whitelisted");
        require(boughtSoFar+sold >= lowCap, "minimum buy not met");
        require(boughtSoFar+sold <= highCap, "Buy limit reached, buy less tokens.");

        uint256 balanceBefore = token.balanceOf(msg.sender);

        // transfer the token to the user
        token.safeTransfer(msg.sender, sold);
        // transfer matic to project
        (bool success,) = payable(_marketingWalletAddress).call{value:msg.value, gas:5000}("");

        require(token.balanceOf(msg.sender) - balanceBefore >= sold, "token transfer failed");
        require(success, "matic transfer failed");

        //update variables
        totalsold += sold;
        user.amountMatic += msg.value;
        user.amountToken += sold;

        // emit buy event for ui
        emit Buy(sold, msg.value, msg.sender);
    }

    function emergencyWithdraw() public onlyOwner {
        // transfer all the remaining tokens to admin
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    // end sale
    function endsale() public onlyOwner {
        // transfer all the remaining tokens to admin
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
        (bool success,) = payable(_marketingWalletAddress).call{value:address(this).balance, gas:5000}("");
        require(success, "transfer failed");
        status = false;
    }
}

