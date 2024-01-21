// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import { IERC165 } from "@openzeppelin/contracts@5.0.0/utils/introspection/ERC165.sol";

interface TokenURIEngine is IERC165 {
    /**
     * @dev Returns the token URI for `tokenId` token.
     * It is one or several properties in JSON format.For example: `"image_url": "https://example.com/p.jpg"`.
     */
    function render(uint256) external view returns (string memory);
}