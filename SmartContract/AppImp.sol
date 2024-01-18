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
    //1.构造函数
    constructor() ERC721("testERC7527App", "test") {}
    
    //预言机？
    address payable private _oracle;
   
    //agency是资产定价合约（管理erc20代币）
    modifier onlyAgency() {
        require(msg.sender == _getAgency(), "only agency");
        _;
    }

    function getName(uint256) external pure returns (string memory) {
        return "App";
    }

    function getMaxSupply() public pure override returns (uint256) {
        return 100;
    }

    function getAgency() external view override returns (address payable) {
        return _getAgency();
    }

    function setAgency(address payable oracle) external override {
        require(_getAgency() == address(0), "already set");
        _oracle = oracle;
    }

    function mint(address to, bytes calldata data) external override onlyAgency returns (uint256 tokenId) {
        require(totalSupply() < getMaxSupply(), "max supply reached");
        tokenId = abi.decode(data, (uint256));
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId, bytes calldata) external override onlyAgency {
        _burn(tokenId);
    }

    function _getAgency() internal view returns (address payable) {
        return _oracle;
    }
}