# demo

### 实验环境
Remix IDE  1.3.6

### 功能
- 部署Factory合约(test.sol)
- 部署（导入）AgencyImp合约(test.sol)
- 部署（导入）AppImp合约(test.sol)
- wrap：erc20代币铸造关于该内容的nft(Agency.sol)
- unwrap：销毁关于改内容的nft，换取erc20代币(Agency.sol)
- 根据tokenid查询每个nft的铸造用户（AppImp.sol）
- 调用预言机进行线性池子计算(Agency.sol)
- token_url的设置和查询(TokenURLEngine.sol,AppImp.sol)
- token引擎和默认引擎的设置与查看(AppImp.sol)
- 用户管理
    - 记录每个参与wrap的用户(地址)(AgencyImp.sol)
    - 限制用户与内容的互动(AgencyImp.sol)