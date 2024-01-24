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
    TokenURIEngine private _TokenEngineImp;
    address payable private _oracle;

    address public factoryAddress;
    address public owner;

    constructor() ERC721(_name, "Reflection") {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    function getOwner() public {
        FactoryImp factory = FactoryImp(factoryAddress);
        owner = factory.getOwner();
    }

    function setMyContractAddress(address _myContractAddress) public {
        factoryAddress = _myContractAddress;
    }

    function puttogether() internal view returns (string memory){
        return string(abi.encodePacked("Reflection", uint256ToString(totalSupply())));
    }
    function uint256ToString(uint256 number) public pure returns (string memory) {
    return number.toString();
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ITokenURISettings).interfaceId || super.supportsInterface(interfaceId);
    }

    function getTokenURIEngine(uint256 tokenId) external view override returns (address) {
        return _tokenURIEngines[tokenId];
    }

    function setTokenURIEngine(uint256 tokenId, address tokenURIEngine) external override{
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
     
    function getProxyTokenURIEngine() external view override returns (address) {
        return address(_TokenEngineImp);
    }
    
    function setProxyTokenURIEngine(address tokenURIEngine) external override onlyOwner(){
        if(tokenURIEngine == address(0)){
            revert InvalidTokenURIEngine(tokenURIEngine);
        }
        address _old = address(_TokenEngineImp);
        _TokenEngineImp = TokenURIEngine(tokenURIEngine);
        emit SetProxyTokenURIEngine(_old, address(_TokenEngineImp));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
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

    function getName(uint256) external view returns (string memory) {
        return _name;
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

    function mint(address to, bytes calldata data) external override  returns (uint256 tokenId) {

        require(totalSupply() < getMaxSupply(), "max supply reached");
        tokenId = abi.decode(data, (uint256));
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId, bytes calldata) external override {

        _burn(tokenId);
    }
    
    function _getAgency() internal view returns (address payable) {
        return _oracle;
    }
}