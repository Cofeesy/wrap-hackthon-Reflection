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
    //给地址类型一种lib，让address类型有一些额外操作
    using Address for address payable;

    struct User {
    address useraddress;//user地址
    //uint256 shares;//份额数量->实现一个nft所有权的分发，每个用户若只能mint一次，那么shares值只能为0或1
    uint256 tokenid;//该用户持有的tokenid
    bool IsHolding;//该用户是否还持有此nft
    bool IsOwnership;//是否是内容创造者
    }
    //记录参与过wrap的用户
    mapping (address => User) countuser;
    address private appImp;
    
    Asset private asset;

    //简易设置，不用constructor
    function setAsset() external  {
            asset.currency = address(0);
            asset.premium = 100000000000000000;
            asset.feeRecipient = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
            asset.mintFeePercent = 10;
            asset.burnFeePercent = 10;
    }

    receive() external payable {}

    //包装->投入erc20代币，如eth，换取该内容的nft
    function wrap(address to, bytes calldata data) external payable override returns (uint256) {
        if (getparticipated(to).useraddress != address(0)){
            require(countuser[msg.sender].IsHolding == false, "Unauthorized Operation");
        }  
        (address _app, Asset memory _asset,) = getStrategy();
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        (uint256 swap, uint256 mintFee) = getWrapOracle(abi.encode(_sold));
        require(msg.value >= swap + mintFee, "AgencyImp: insufficient funds");
        //第一个传参是asset里的代币地址，0默认为ETH，既让feeRecipient收到mintFee
        _transfer(address(0), _asset.feeRecipient, mintFee);
        //若用户余额大于总费用，将多余的ETH还给msg.sender
        if (msg.value > swap + mintFee) {
            //逻辑是转swap和mintFee,,既对msg.sender的msg.value操作,将(msg.value - swap - mintFee)既剩余的value转给用户,swap保留在本合约,mintfee给feeRecipient
            _transfer(address(0), payable(msg.sender), msg.value - swap - mintFee);
        }
        uint256 id_ = IERC7527App(_app).mint(to, data);
        //如果
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
    
    //解包装
    function unwrap(address to, uint256 tokenId, bytes calldata data) external payable override {
        (address _app, Asset memory _asset,) = getStrategy();
        require(_isApprovedOrOwner(_app, msg.sender, tokenId), "LnModule: not owner");
        IERC7527App(_app).burn(tokenId, data);
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        (uint256 swap, uint256 burnFee) = getUnwrapOracle(abi.encode(_sold));
        //给to地址转(swap-burnFee)数量的的ETH
        _transfer(address(0), payable(to), swap - burnFee);
        //给feeRecipient转burnFee
        _transfer(address(0), _asset.feeRecipient, burnFee);
        require(countuser[msg.sender].IsHolding == true, "Unauthorized Operation");
        countuser[to].IsHolding = false;
        emit Unwrap(to, tokenId, swap, burnFee);
    }
    
    //获取app，asset
    function getStrategy() public view override returns (address app, Asset memory asset_, bytes memory attributeData) {
        Asset memory _asset = Asset(address(0), 100000000000000000, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10, 10);    
        app = getAppImpAddress();
        attributeData = "";
        return (app, _asset, attributeData);
    }
    
    //计算用户wrap需要投入的费用以及手续费 
    function getWrapOracle(bytes memory data) public view override returns (uint256 swap, uint256 fee) {
        uint256 input = abi.decode(data, (uint256));
        //
        (, Asset memory _asset,) = getStrategy();
        //计算的逻辑是第一种线性变化：逻辑是随着资产铸造的次数增加，资产的价格也会随之上升
        //y = k +(x*k)/100
          //k是premium,x是wrap调用次数->既input
        swap = _asset.premium + input * _asset.premium / 100;
        //计算手续费
        //如果部署者设置 mintFeePercent 为 500，其实际费率为 500 / 10000 = 5%
        fee = swap * _asset.mintFeePercent / 10000;
    }

    //计算用户unwrap收到的费用以及投入的手续费 
    function getUnwrapOracle(bytes memory data) public view override returns (uint256 swap, uint256 fee) {
        uint256 input = abi.decode(data, (uint256));
        (, Asset memory _asset,) = getStrategy();
        swap = _asset.premium + input * _asset.premium / 100;
        fee = swap * _asset.burnFeePercent / 10000;
    }
    
    //获取参与过的用户信息
    function getparticipated(address somebody) public view returns(User memory){
        //require(countuser[somebody].useraddress != address(0), "Unauthorized Operation" );
        return countuser[somebody];
    }
    
    //内部转账
    function _transfer(address currency, address recipient, uint256 premium) internal {
        //若地址为0，则默认为ETH
        if (currency == address(0)) {
            //使用到了Address的lib所拥有的方法->sendValue
            //function sendValue(address payable recipient, uint256 amount) internal 
            //recipient收到premium的费用
            //底层的sendValue函数是低级的调用（call）方法，当前合约将amount数量的以太币转账给名为recipient的合约地址
            payable(recipient).sendValue(premium);
        } else {
            //若是其他ERC20代币,执行transfer
            IERC20(currency).transfer(recipient, premium);
        }
    }

    //获取AppImp合约地址
    function getAppImpAddress() public view returns(address){
        return appImp;
    }

    //手动设置AppImp合约地址
    function setAppImpAddress(address _AppImp) external{
        appImp = _AppImp;
    }

    //1:0x0000000000000000000000000000000000000000000000000000000000000001
    //2:0x0000000000000000000000000000000000000000000000000000000000000002
    function encode(uint256 data ) public returns(bytes memory) {
        return abi.encode(data);
    }

    //检查函数
    function _isApprovedOrOwner(address app, address spender, uint256 tokenId) internal view virtual returns (bool) {
        IERC721Enumerable _app = IERC721Enumerable(app);
        address _owner = _app.ownerOf(tokenId);
        return (spender == _owner || _app.isApprovedForAll(_owner, spender) || _app.getApproved(tokenId) == spender);
    }
    /// @return offset The offset of the packed immutable args in calldata

}