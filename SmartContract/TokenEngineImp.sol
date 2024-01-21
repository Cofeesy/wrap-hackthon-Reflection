// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { TokenURIEngine } from "./interfaces/TokenURIEngine.sol";
import { IERC165, ERC165 } from "@openzeppelin/contracts@5.0.0/utils/introspection/ERC165.sol";

contract MiniTokenEngine is TokenURIEngine, ERC165 {
    mapping(address => mapping(uint256 => address)) user;
    
    //tokenid还未使用
    function render(uint256 tokenId) external override pure returns (string memory) {
        return string(abi.encodePacked('"image": "', 'https://blogimage.4everland.store/DiscreteGDA.png"'));
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(TokenURIEngine).interfaceId || super.supportsInterface(interfaceId);
    }
}