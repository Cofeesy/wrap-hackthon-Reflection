// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {IERC7527Factory, AgencySettings, AppSettings} from "./interfaces/IERC7527Factory.sol";

contract FactoryImp is IERC7527Factory{
    //汇编相关？？
    using ClonesWithImmutableArgs for address;


    // //传参1:agency配置
        //struct AgencySettings {
            //agency合约实现地址？
        //  address payable implementation;
            //资产结构体
        //  Asset asset;
            //
        //  bytes immutableData;
            //
        //  bytes initData;
    //  }
    //部署app,agency合约
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
}