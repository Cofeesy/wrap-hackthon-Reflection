// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {IERC7527Factory, AgencySettings, AppSettings} from "./interfaces/IERC7527Factory.sol";

contract FactoryImp is IERC7527Factory{
    using ClonesWithImmutableArgs for address;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deployWrap(AgencySettings calldata agencySettings, AppSettings calldata appSettings, bytes calldata)
        external
        override
        returns (address appInstance, address agencyInstance)
    {
        appInstance = appSettings.implementation.clone(appSettings.immutableData);
        {
            agencyInstance = address(agencySettings.implementation).clone(
                abi.encodePacked(
                    appInstance,
                    agencySettings.asset.currency,
                    agencySettings.asset.premium,
                    agencySettings.asset.feeRecipient,
                    agencySettings.asset.mintFeePercent,
                    agencySettings.asset.burnFeePercent,
                    agencySettings.immutableData
                )
            );
        }
    }

    function getOwner() public view returns (address) {
        return owner;
    }
}