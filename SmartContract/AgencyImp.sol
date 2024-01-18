// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//导入agency接口包，以及所定义的asset结构体
import {
    IERC7527Agency,
    //因此,这里有一个隐藏的asset结构体
    Asset
} from "./interfaces/IERC7527Agency.sol";

//导入Address这个lib包
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
//不太懂这个包，内联汇编的东西？
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

    function wrap(address to, bytes calldata data) external payable override returns (uint256) {
        //getStrategy获取app合约地址，获取此asset资产
        //问题，获取哪个app合约地址？
        (address _app, Asset memory _asset,) = getStrategy();
        //返回当前app中铸造nft的总数
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        //将uint256类型的_sold打包成字节，调用预言机获取mint手续费以及用户需要投入的erc20代币费用(数量)
        (uint256 swap, uint256 mintFee) = getWrapOracle(abi.encode(_sold));
        //门槛？用户余额需要大于计算出来需要投入的总费用->那就是用户参与实在费用上有门槛的
        require(msg.value >= swap + mintFee, "ERC7527Agency: insufficient funds");
        //转移代币至feeRecipient(手续费接收地址)
        //地址为0的用户转入？->下文的function _transfer(address currency, address recipient, uint256 premium) internal
        //第一个传参是asset里的代币地址，0默认为ETH，既让feeRecipient收到mintFee
        _transfer(address(0), _asset.feeRecipient, mintFee);
        //若用户余额大于总费用，将多余的ETH还给msg.sender
        if (msg.value > swap + mintFee) {//这步判断不会多余吗?
            //逻辑是转swap和mintFee,,既对msg.sender的msg.value操作,将(msg.value - swap - mintFee)既剩余的value转给用户,swap保留在本合约,mintfee给feeRecipient
            //前面的transfer是将本合约的本该属于用户交的mintFee先转给feeRecipient,后面本合约多交出去的mintFee由用户补上
            _transfer(address(0), payable(msg.sender), msg.value - swap - mintFee);
        }
        //mint一个nft,这个id是递增吗?是的,是递增的,app基本上是一个标准nft合约,因此id是依次递增的
        uint256 id_ = IERC7527App(_app).mint(to, data);
        //检查nft数量
        require(_sold + 1 == IERC721Enumerable(_app).totalSupply(), "ERC7527Agency: Reentrancy");
        //提交事件
        emit Wrap(to, id_, swap, mintFee);
        //返回nft_id
        return id_;
    }

    //
    function unwrap(address to, uint256 tokenId, bytes calldata data) external payable override {
        //getStrategy获取app合约地址，获取此asset资产
        (address _app, Asset memory _asset,) = getStrategy();
        //解质押操作的用户为 NFT 的所有权(包含直接持有 NFT 或者被 NFT 持有者 approve 两种情况)
        require(_isApprovedOrOwner(_app, msg.sender, tokenId), "LnModule: not owner");
        //burn掉对应tokenId的nft
        IERC7527App(_app).burn(tokenId, data);
        //获取已mint的nft总数
        uint256 _sold = IERC721Enumerable(_app).totalSupply();
        //对_sol进行字节打包,通过预言机获取swap和burnFee
        (uint256 swap, uint256 burnFee) = getUnwrapOracle(abi.encode(_sold));
        //给to地址转(swap-burnFee)数量的的ETH
        _transfer(address(0), payable(to), swap - burnFee);
        //给feeRecipient转burnFee
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

    //预言机：实时计算获取wrap所需要支付的erc20代币数量，以及wrap(mint)的手续费
    function getWrapOracle(bytes memory data) public pure override returns (uint256 swap, uint256 fee) {
        //获取调用次数->本质调用wrap一次,nft数量就会+1.于是上面用的nft的totalSupply
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

    //预言机：实时计算获取unwrap所收到的erc20代币数量，以及unwrap(burn)的手续费
    //Umwrap和wrap具有对称性，既计算逻辑是一样的，都是基于现有的asset中erc20代币和app中nft的数量计算，只是执行逻辑不同
    function getUnwrapOracle(bytes memory data) public pure override returns (uint256 swap, uint256 fee) {
        uint256 input = abi.decode(data, (uint256));
        (, Asset memory _asset,) = getStrategy();
        swap = _asset.premium + input * _asset.premium / 100;
        fee = swap * _asset.burnFeePercent / 10000;
    }

    //转账(swap和fee)
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

    //检查函数
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