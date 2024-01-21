// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//这个导入的用处：Clone factory contracts->By doing so, the gas cost of creating parametrizable clones is reduced
//额外:在 EIP1167 基础上增加了为 clone 合约提供初始化参数的能力
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
//导入
import {IERC7527Factory, AgencySettings, AppSettings} from "./interfaces/IERC7527Factory.sol";

//内容创造者使用Factory合约部署自己的app和agency合约
//那内容url怎么加入？
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
        //
        appInstance = appSettings.implementation.clone(appSettings.immutableData);
        {
            //这个怎么理解？
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