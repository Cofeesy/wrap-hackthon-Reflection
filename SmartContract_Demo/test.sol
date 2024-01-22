// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AgencyImp} from "./ReflectionAgencyImp.sol";
import {AppImp} from "./ReflectionAppImp.sol";
import {FactoryImp} from "./ReflectionFactoryImp.sol";
import {IERC7527App} from "./Interfaces/IERC7527App.sol";
import {IERC7527Agency, Asset} from "./interfaces/IERC7527Agency.sol";
import {IERC7527Factory, AgencySettings, AppSettings} from "./interfaces/IERC7527Factory.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract test{
    AgencyImp public agency;//Agency合约实例
    AppImp public app;//App合约实例

    FactoryImp public factory;//Factory合约实例

    //ERC7527WarpReentrancy public warpReentrancy;

    address public appDeployAddress;
    address public agencyDeployAddress;

    receive() external payable {}

    function setUp() public{
        agency = new AgencyImp();
        app = new AppImp();

        factory = new FactoryImp();

        Asset memory asset = Asset({
            currency: address(0),
            premium: 0.1 ether,
            feeRecipient: address(1),
            mintFeePercent: uint16(10),
            burnFeePercent: uint16(10)
        });

        AgencySettings memory agencySettings = AgencySettings({
            implementation: payable(address(agency)),
            asset: asset,
            immutableData: bytes(""),
            initData: bytes("")
        });

        AppSettings memory appSettings =
            AppSettings({implementation: address(app), immutableData: bytes(""), initData: bytes("")});

        (appDeployAddress, agencyDeployAddress) = factory.deployWrap(agencySettings, appSettings, bytes(""));
}
    

    
}
    