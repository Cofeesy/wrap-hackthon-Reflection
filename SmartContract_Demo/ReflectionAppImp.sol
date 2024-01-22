// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC7527App} from "./Interfaces/IERC7527App.sol";
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
import {FactoryImp} from "./ReflectionFactoryImp.sol";

contract AppImp is IERC7527App, ERC721Enumerable, ITokenURISettings{
    using Strings for uint256;
    string private _name = puttogether();
    string private _symbol;
    mapping(uint256 => address) private _tokenURIEngines;
   //没变化前，是旧的代理引擎
    TokenURIEngine private _TokenEngineImp;
    address payable private _oracle;

    address public factoryAddress;
    address public owner;

    constructor() ERC721(_name, "Reflection") {}

    //暂时无用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    //获取初始调用工厂合约的地址，既内容创造者的地址，暂时无用
    function getOwner() public {
        FactoryImp factory = FactoryImp(factoryAddress);
        owner = factory.getOwner();
    }

    //设置工厂合约，暂时无用
    function setMyContractAddress(address _myContractAddress) public {
        factoryAddress = _myContractAddress;
    }

    //拼接_name
    function puttogether() internal view returns (string memory){
        return string(abi.encodePacked("Reflection", uint256ToString(totalSupply())));
    }
    //功能函数:uint256转为string类型
    function uint256ToString(uint256 number) public pure returns (string memory) {
    return number.toString();
    }
    
    //erc165接口函数
    //功能：检测到一个智能合约实现了什么接口的标准
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ITokenURISettings).interfaceId || super.supportsInterface(interfaceId);
    }


    //获取tokenURL引擎
    function getTokenURIEngine(uint256 tokenId) external view override returns (address) {
        return _tokenURIEngines[tokenId];
    }

    //设置tokenURL引擎
    function setTokenURIEngine(uint256 tokenId, address tokenURIEngine) external override{
        //检查是否存在此tokenid
        address tokenowner = _ownerOf(tokenId);
        if (tokenowner == address(0)) {
            revert TokenURISettingsNonexistentToken(tokenId);
        }
        if(tokenURIEngine == address(0)){
            revert InvalidTokenURIEngine(tokenURIEngine);
        }
        _tokenURIEngines[tokenId] = tokenURIEngine;
        emit SetTokenURIEngine(tokenId, tokenURIEngine);
    }
     
    //获取url代理引擎合约地址
    function getProxyTokenURIEngine() external view override returns (address) {
        return address(_TokenEngineImp);
    }
    
    //设置代理URL引擎
    function setProxyTokenURIEngine(address tokenURIEngine) external override onlyOwner(){
        if(tokenURIEngine == address(0)){
            revert InvalidTokenURIEngine(tokenURIEngine);
        }
        address _old = address(_TokenEngineImp);
        //设置新的
        _TokenEngineImp = TokenURIEngine(tokenURIEngine);
        //event SetProxyTokenURIEngine(address oldTokenURIEngine, address indexed newTokenURIEngine);
        emit SetProxyTokenURIEngine(_old, address(_TokenEngineImp));
    }
    //此合约查看tokenurl的函数 -> 调用引擎的render函数
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        //同样，检查token是否存在
        address tokenowner = _ownerOf(tokenId);
        if (tokenowner == address(0)) {
            revert TokenURISettingsNonexistentToken(tokenId);
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
    //设置agency合约地址,暂时无用
    function setAgency(address payable oracle) external override {
        require(_getAgency() == address(0), "already set");
        _oracle = oracle;
    }
    //铸造nft
    function mint(address to, bytes calldata data) external override  returns (uint256 tokenId) {
        //nft总数检查
        require(totalSupply() < getMaxSupply(), "max supply reached");
        tokenId = abi.decode(data, (uint256));
        //调用的内部函数_mint，内部函数就是检查0地址
        _mint(to, tokenId);
    }
    //销毁nft
    function burn(uint256 tokenId, bytes calldata) external override {
        //调用的内部函数_burn，内部函数就是检查0地址
        _burn(tokenId);
    }
    //获取agency合约地址-->内部调用
    function _getAgency() internal view returns (address payable) {
        return _oracle;
    }
}