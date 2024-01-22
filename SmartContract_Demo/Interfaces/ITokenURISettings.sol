// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

interface ITokenURISettings {
// events
    event SetTokenURIEngine(uint256 indexed tokenId, address indexed tokenURIEngine);
    event SetProxyTokenURIEngine(address oldTokenURIEngine, address indexed newTokenURIEngine);

    // errors
    error NotOwnerOrApproved();
    error InvalidTokenURIEngine(address tokenURIEngine);
    error TokenURISettingsNonexistentToken(uint256 tokenId);

    /**
     * @param tokenId The token id of the NFT.
     * @return The address of the tokenURIEngine. If the tokenURIEngine is not set, return the default tokenURIEngine.
     */
    function getTokenURIEngine(uint256 tokenId) external view returns (address);

    /**
     *
     * @param tokenId The token id of the NFT.
     * @param tokenURIEngine The address of the tokenURIEngine which must be immpelment ITokenURIEngine interface.
     */
    function setTokenURIEngine(uint256 tokenId, address tokenURIEngine) external;

    /**
     * 
     * @return The address of tokenURIEngine that is for the proxy.
     */
    function getProxyTokenURIEngine() external view returns (address);

    /**
     *
     * @param tokenURIEngine The address of the tokenURIEngine which must be immpelment ITokenURIEngine interface.
     */
    function setProxyTokenURIEngine(address tokenURIEngine) external;
}