// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC7527App} from "./Interfaces/IERC7527App.sol";

//Enumerable:对NFT数量计数
import {
    ERC721Enumerable,
    ERC721,
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

//NFT合约
contract AppImp is IERC7527App, ERC721Enumerable{
    //1.ERC721构造函数
    constructor() ERC721("testERC7527App", "test") {}
    //预言机？
    address payable private _oracle;
    //agency是资产定价合约（管理erc20代币）
    modifier onlyAgency() {
        require(msg.sender == _getAgency(), "only agency");
        _;
    }
    //获取nft名字
    function getName(uint256) external pure returns (string memory) {
        return "App";
    }
    //获取最大nft供应量
    function getMaxSupply() public pure override returns (uint256) {
        return 100;
    }
    //获取agency合约地址-->外部调用
    function getAgency() external view override returns (address payable) {
        return _getAgency();
    }
    //设置agency合约地址
    function setAgency(address payable oracle) external override {
        require(_getAgency() == address(0), "already set");
        _oracle = oracle;
    }
    //只有agency(代币管理合约)才能铸造nft
    function mint(address to, bytes calldata data) external override onlyAgency returns (uint256 tokenId) {
        //nft总数检查
        require(totalSupply() < getMaxSupply(), "max supply reached");
        tokenId = abi.decode(data, (uint256));
        //调用的内部函数_mint，内部函数就是检查0地址
        _mint(to, tokenId);
        //function _mint(address to, uint256 tokenId) internal {
        //if (to == address(0)) {
        //    revert ERC721InvalidReceiver(address(0));
        //}
        //address previousOwner = _update(to, tokenId, address(0));
        //if (previousOwner != address(0)) {
        //    revert ERC721InvalidSender(address(0));
        //}
    //}
    }
    //只有agency(代币管理合约)才能销毁nft
    function burn(uint256 tokenId, bytes calldata) external override onlyAgency {
        //调用的内部函数_burn，内部函数就是检查0地址
        _burn(tokenId);
        //function _burn(uint256 tokenId) internal {
        //address previousOwner = _update(address(0), tokenId, address(0));
        //if (previousOwner == address(0)) {
        //    revert ERC721NonexistentToken(tokenId);
        //}
    //}
    }
    //获取agency合约地址-->内部调用
    function _getAgency() internal view returns (address payable) {
        return _oracle;
    }
}