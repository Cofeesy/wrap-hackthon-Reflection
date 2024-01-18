// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//导入agency接口包，以及所定义的asset结构体
import {
    IERC7527Agency,
    Asset
} from "./interfaces/IERC7527Agency.sol";

//导入Address这个lib包
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
//
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
//导入erc721标准格式包，以及erc721计数合约和标准接口
import {
    ERC721Enumerable,
    ERC721,
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
//导入app接口包
import {IERC7527App} from "./Interfaces/IERC7527App.sol";
//导入标准erc20接口包
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AgencyImp is IERC7527Agency{
    //给地址类型一种lib，让address类型有一些额外操作
    using Address for address payable;
    //address.sendValue(address(0),1);

    //仅nft合约(app合约)地址可操作
    modifier onlyApp() {
        //offset:偏移量
        uint256 offset = _getImmutableArgsOffset();
        address app;
        assembly {
            //后面的getstrategy -> app := shr(0x60, calldataload(add(offset, 0)))
            //有什么不同？
            app := shr(0x60, calldataload(add(offset, 76)))
        }
        //仅app合约可操作，否则报错
        require(msg.sender == app, "ERC7527Agency: caller is not the app");
        //执行接下来的修饰函数
        _;
    }
    //定义这个合约可接收eth
    receive() external payable {}

    //
    function wrap(address to, bytes calldata data) external payable override returns (uint256) {
        //getStrategy获取app合约地址，获取此asset资产
        //问题，获取哪个app合约地址？
        (address _app, Asset memory _asset,) = getStrategy();
        //返回当前app中铸造nft的总数
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        //
        (uint256 swap, uint256 mintFee) = getWrapOracle(abi.encode(_sold));
        //
        require(msg.value >= swap + mintFee, "ERC7527Agency: insufficient funds");
        //转移代币至feeRecipient(手续费接受地址)
        _transfer(address(0), _asset.feeRecipient, mintFee);
        //
        if (msg.value > swap + mintFee) {
            _transfer(address(0), payable(msg.sender), msg.value - swap - mintFee);
        }
        //
        uint256 id_ = IERC7527App(_app).mint(to, data);
        //
        require(_sold + 1 == IERC721Enumerable(_app).totalSupply(), "ERC7527Agency: Reentrancy");
        //
        emit Wrap(to, id_, swap, mintFee);
        //
        return id_;
    }

    //
    function unwrap(address to, uint256 tokenId, bytes calldata data) external payable override {
        //getStrategy获取app合约地址，获取此asset资产
        (address _app, Asset memory _asset,) = getStrategy();
        //
        require(_isApprovedOrOwner(_app, msg.sender, tokenId), "LnModule: not owner");
        //
        IERC7527App(_app).burn(tokenId, data);
        //
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        //
        (uint256 swap, uint256 burnFee) = getUnwrapOracle(abi.encode(_sold));
        //
        _transfer(address(0), payable(to), swap - burnFee);
        //
        _transfer(address(0), _asset.feeRecipient, burnFee);
        emit Unwrap(to, tokenId, swap, burnFee);
    }

    function getStrategy() public pure override returns (address app, Asset memory asset, bytes memory attributeData) {
        //offset
        uint256 offset = _getImmutableArgsOffset();
        
        //一些接收变量
        address currency;
        uint256 premium;
        address payable awardFeeRecipient;
        uint16 mintFeePercent;
        uint16 burnFeePercent;
       
        //内联汇编-作用:根据位置从字节码中提取对应的数据
        assembly {
            app := shr(0x60, calldataload(add(offset, 0)))
            currency := shr(0x60, calldataload(add(offset, 20)))
            premium := calldataload(add(offset, 40))
            awardFeeRecipient := shr(0x60, calldataload(add(offset, 72)))
            mintFeePercent := shr(0xf0, calldataload(add(offset, 92)))
            burnFeePercent := shr(0xf0, calldataload(add(offset, 94)))
        }
        //构建需要返回的asset
        asset = Asset(currency, premium, awardFeeRecipient, mintFeePercent, burnFeePercent);
        
        //这是什么？      
        attributeData = "";
    }

    //预言机：实时计算获取unwrap所收到的erc20代币数量，以及unwrap(burn)的手续费
    function getUnwrapOracle(bytes memory data) public pure override returns (uint256 swap, uint256 fee) {
        //
        uint256 input = abi.decode(data, (uint256));
        //
        (, Asset memory _asset,) = getStrategy();
        //
        swap = _asset.premium + input * _asset.premium / 100;
        //
        fee = swap * _asset.burnFeePercent / 10000;
    }

    //预言机：实时计算获取wrap所需要支付的erc20代币数量，以及wrap(mint)的手续费
    function getWrapOracle(bytes memory data) public pure override returns (uint256 swap, uint256 fee) {
        //
        uint256 input = abi.decode(data, (uint256));
        //
        (, Asset memory _asset,) = getStrategy();
        //
        swap = _asset.premium + input * _asset.premium / 100;
        //
        fee = swap * _asset.mintFeePercent / 10000;
    }

    //
    function _transfer(address currency, address recipient, uint256 premium) internal {
        if (currency == address(0)) {
            //使用到了Address的lib所拥有的方法->sendValue
            //function sendValue(address payable recipient, uint256 amount) internal 
            payable(recipient).sendValue(premium);
        } else {
            IERC20(currency).transfer(recipient, premium);
        }
    }

    //
    function _isApprovedOrOwner(address app, address spender, uint256 tokenId) internal view virtual returns (bool) {
        IERC721Enumerable _app = IERC721Enumerable(app);
        address _owner = _app.ownerOf(tokenId);
        return (spender == _owner || _app.isApprovedForAll(_owner, spender) || _app.getApproved(tokenId) == spender);
    }
    /// @return offset The offset of the packed immutable args in calldata

    //
    function _getImmutableArgsOffset() internal pure returns (uint256 offset) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            offset := sub(calldatasize(), add(shr(240, calldataload(sub(calldatasize(), 2))), 2))
        }
    }
}