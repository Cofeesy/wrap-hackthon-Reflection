// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC7527App} from "./Interfaces/IERC7527App.sol";

//Enumerable:对NFT数量计数
import {
    ERC721Enumerable,
    ERC721,
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import "./Interfaces/ITokenURISettings.sol";
import "./Interfaces/TokenURIEngine.sol";
import {TokenEngineImp} from "./TokenEngineImp.sol";
import "@openzeppelin/contracts@5.0.0/utils/introspection/ERC165.sol";

//NFT合约
contract AppImp is IERC7527App, ERC721Enumerable, ITokenURISettings{
    using Strings for uint256;
    // Token name
    string private _name = puttogether();
    // Token symbol
    string private _symbol;
    //tokenid对应的URIEngine
    mapping(uint256 => address) private _tokenURIEngines;
   //没变化前，是旧的代理引擎
    TokenURIEngine private _TokenEngineImp;
    //预言机
    address payable private _oracle;

    //拼接_name
    function puttogether() internal view returns (string memory){
        return string(abi.encodePacked("Reflection", uint256ToString(totalSupply())));
    }
    //功能函数:uint256转为string类型
    function uint256ToString(uint256 number) public pure returns (string memory) {
    return number.toString();
    }

    //ERC721构造函数
    //
    constructor() ERC721(_name, "Reflection") {}
    
    //erc165接口函数
    //功能：检测到一个智能合约实现了什么接口的标准
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ITokenURISettings).interfaceId || super.supportsInterface(interfaceId);
    }

    //agency是资产定价合约（管理erc20代币）
    modifier onlyAgency() {
        require(msg.sender == _getAgency(), "only agency");
        _;
    }

    //获取tokenURL引擎
    function getTokenURIEngine(uint256 tokenId) external view override returns (address) {
        return _tokenURIEngines[tokenId];
    }

    //设置每个不同的tokenURL引擎
    function setTokenURIEngine(uint256 tokenId, address tokenURIEngine) external override {
        //检查是否存在此tokenid
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }else if (msg.sender != owner || isApprovedForAll(owner, msg.sender)){
            revert ERC721InvalidApprover(msg.sender);
        }  
        _tokenURIEngines[tokenId] = tokenURIEngine;
        emit SetTokenURIEngine(tokenId, tokenURIEngine);
    }

    function getProxyTokenURIEngine() external view override returns (address) {
        return address(_TokenEngineImp);
    }
    
    //设置代理URL引擎
    function setProxyTokenURIEngine(address tokenURIEngine) external override {
        address _old = address(_TokenEngineImp);
        //设置新的
        _TokenEngineImp = TokenURIEngine(tokenURIEngine);
        //event SetProxyTokenURIEngine(address oldTokenURIEngine, address indexed newTokenURIEngine);
        emit SetProxyTokenURIEngine(_old, address(_TokenEngineImp));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        //同样，检查token是否存在
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        address tokenURIEngine = _tokenURIEngines[tokenId];
        if (tokenURIEngine != address(0)) {
            return TokenURIEngine(tokenURIEngine).render(tokenId);
        }

        return _TokenEngineImp.render(tokenId);
    }

    //获取nft名字
    function getName(uint256) external view returns (string memory) {
        return _name;
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