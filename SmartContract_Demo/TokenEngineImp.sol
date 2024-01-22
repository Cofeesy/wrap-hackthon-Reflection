// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { TokenURIEngine } from "./interfaces/TokenURIEngine.sol";
import { IERC165, ERC165 } from "@openzeppelin/contracts@5.0.0/utils/introspection/ERC165.sol";

contract TokenEngineImp is TokenURIEngine, ERC165 {
    mapping(uint256 => string) private _tokenURIs;
    
    //返回URI
    function render(uint256 tokenId) external view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    //url引擎设置用户URI
    function setTokenURI(uint256 tokenId, string memory tokenURI) external {
        _tokenURIs[tokenId] = tokenURI;
    }



    //IPFS
    //function setTokenURI(uint256 tokenId, string memory ipfsCid) external {
    //    _tokenURIs[tokenId] = string(abi.encodePacked("ipfs://", ipfsCid));
    //}
}