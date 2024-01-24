// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    IERC7527Agency,
    Asset
} from "./interfaces/IERC7527Agency.sol";
import {AppImp} from "./ReflectionAppImp.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {
    ERC721Enumerable,
    ERC721,
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC7527App} from "./Interfaces/IERC7527App.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AgencyImp is IERC7527Agency{
    using Address for address payable;

    struct User {
    address useraddress;
    uint256 tokenid;
    bool IsHolding;
    bool IsOwnership;
    }

    mapping (address => User) countuser;
    address private appImp;
    
    Asset private asset;

    function setAsset() external  {
            asset.currency = address(0);
            asset.premium = 100000000000000000;
            asset.feeRecipient = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
            asset.mintFeePercent = 10;
            asset.burnFeePercent = 10;
    }

    receive() external payable {}

    function wrap(address to, bytes calldata data) external payable override returns (uint256) {
        if (getparticipated(to).useraddress != address(0)){
            require(countuser[msg.sender].IsHolding == false, "Unauthorized Operation");
        }  
        (address _app, Asset memory _asset,) = getStrategy();
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        (uint256 swap, uint256 mintFee) = getWrapOracle(abi.encode(_sold));
        require(msg.value >= swap + mintFee, "AgencyImp: insufficient funds");
        _transfer(address(0), _asset.feeRecipient, mintFee);
        if (msg.value > swap + mintFee) {
            _transfer(address(0), payable(msg.sender), msg.value - swap - mintFee);
        }
        uint256 id_ = IERC7527App(_app).mint(to, data);
        if (getparticipated(to).useraddress == address(0)){
            User memory user; 
            user.useraddress = msg.sender;
            user.IsOwnership = false;
            user.IsHolding = true;
            user.tokenid = id_;
            countuser[to] = user;
        }else{
            countuser[to].IsHolding = true;   
        }
        require(_sold + 1 == IERC721Enumerable(_app).totalSupply(), "AgencyImp: Reentrancy");
        emit Wrap(to, id_, swap, mintFee);
        return id_;
    }
    
    function unwrap(address to, uint256 tokenId, bytes calldata data) external payable override {
        (address _app, Asset memory _asset,) = getStrategy();
        require(_isApprovedOrOwner(_app, msg.sender, tokenId), "LnModule: not owner");
        IERC7527App(_app).burn(tokenId, data);
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        (uint256 swap, uint256 burnFee) = getUnwrapOracle(abi.encode(_sold));
        _transfer(address(0), payable(to), swap - burnFee);
        _transfer(address(0), _asset.feeRecipient, burnFee);
        require(countuser[msg.sender].IsHolding == true, "Unauthorized Operation");
        countuser[to].IsHolding = false;
        emit Unwrap(to, tokenId, swap, burnFee);
    }
    
    function getStrategy() public view override returns (address app, Asset memory asset_, bytes memory attributeData) {
        Asset memory _asset = Asset(address(0), 100000000000000000, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10, 10);    
        app = getAppImpAddress();
        attributeData = "";
        return (app, _asset, attributeData);
    }
    
    function getWrapOracle(bytes memory data) public view override returns (uint256 swap, uint256 fee) {
        uint256 input = abi.decode(data, (uint256));
        (, Asset memory _asset,) = getStrategy();
        swap = _asset.premium + input * _asset.premium / 100;
        fee = swap * _asset.mintFeePercent / 10000;
    }

    function getUnwrapOracle(bytes memory data) public view override returns (uint256 swap, uint256 fee) {
        uint256 input = abi.decode(data, (uint256));
        (, Asset memory _asset,) = getStrategy();
        swap = _asset.premium + input * _asset.premium / 100;
        fee = swap * _asset.burnFeePercent / 10000;
    }
    
    function getparticipated(address somebody) public view returns(User memory){
        return countuser[somebody];
    }
    
    function _transfer(address currency, address recipient, uint256 premium) internal {
        if (currency == address(0)) {
            payable(recipient).sendValue(premium);
        } else {
            IERC20(currency).transfer(recipient, premium);
        }
    }

    function getAppImpAddress() public view returns(address){
        return appImp;
    }

    function setAppImpAddress(address _AppImp) external{
        appImp = _AppImp;
    }

    function encode(uint256 data ) public returns(bytes memory) {
        return abi.encode(data);
    }

    function _isApprovedOrOwner(address app, address spender, uint256 tokenId) internal view virtual returns (bool) {
        IERC721Enumerable _app = IERC721Enumerable(app);
        address _owner = _app.ownerOf(tokenId);
        return (spender == _owner || _app.isApprovedForAll(_owner, spender) || _app.getApproved(tokenId) == spender);
    }

}