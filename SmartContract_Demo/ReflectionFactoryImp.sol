// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//这个导入的用处：Clone factory contracts->By doing so, the gas cost of creating parametrizable clones is reduced
//额外:在 EIP1167 基础上增加了为 clone 合约提供初始化参数的能力
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
//导入
import {IERC7527Factory, AgencySettings, AppSettings} from "./interfaces/IERC7527Factory.sol";

contract FactoryImp is IERC7527Factory{
    using ClonesWithImmutableArgs for address;
    address public owner;
    //暂时没用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    //部署app,agency合约
    function deployWrap(AgencySettings calldata agencySettings, AppSettings calldata appSettings, bytes calldata)
        external
        override
        returns (address appInstance, address agencyInstance)
    {
        //
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
    //暂时没用
    function getOwner() public view returns (address) {
        return owner;
    }
}