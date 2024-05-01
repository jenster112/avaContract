// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

library Constants {

    address public constant PYTH_BASE_SEPOLIA = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
    address public constant PYTH_BASE_GOERLI = 0x5955C1478F0dAD753C7E2B4dD1b4bC530C64749f;
    address public constant PYTH_BASE_MAINNET = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;
    
/********************************************PYTH FEED IDs************************************************************/

    bytes32 public constant PYTH_ETH_USD_FEED_BASE_SEPOLIA = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    bytes32 public constant PYTH_ETH_USD_FEED_BASE_GOERLI = 0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6;
    bytes32 public constant PYTH_ETH_USD_FEED_BASE_MAINNET = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    bytes32 public constant PYTH_BTC_USD_FEED_BASE_SEPOLIA = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    bytes32 public constant PYTH_BTC_USD_FEED_BASE_GOERLI = 0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b;
    bytes32 public constant PYTH_BTC_USD_FEED_BASE_MAINNET = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

    bytes32 public constant PYTH_JPY_USD_FEED_BASE_SEPOLIA = 0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52;
    bytes32 public constant PYTH_JPY_USD_FEED_BASE_GOERLI = 0x20a938f54b68f1f2ef18ea0328f6dd0747f8ea11486d22b021e83a900be89776;
    bytes32 public constant PYTH_JPY_USD_FEED_BASE_MAINNET = 0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52;

    bytes32 public constant PYTH_GBP_USD_FEED_BASE_SEPOLIA = 0x84c2dde9633d93d1bcad84e7dc41c9d56578b7ec52fabedc1f335d673df0a7c1;
    bytes32 public constant PYTH_GBP_USD_FEED_BASE_GOERLI = 0xbcbdc2755bd74a2065f9d3283c2b8acbd898e473bdb90a6764b3dbd467c56ecd;
    bytes32 public constant PYTH_GBP_USD_FEED_BASE_MAINNET = 0x84c2dde9633d93d1bcad84e7dc41c9d56578b7ec52fabedc1f335d673df0a7c1;

    bytes32 public constant PYTH_EUR_USD_FEED_BASE_SEPOLIA = 0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b;
    bytes32 public constant PYTH_EUR_USD_FEED_BASE_GOERLI = 0xc1b12769f6633798d45adfd62bfc70114839232e2949b01fb3d3f927d2606154;
    bytes32 public constant PYTH_EUR_USD_FEED_BASE_MAINNET = 0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b;

    //Silver
    bytes32 public constant PYTH_XAG_USD_FEED_BASE_SEPOLIA = 0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e;
    bytes32 public constant PYTH_XAG_USD_FEED_BASE_GOERLI = 0x321ba4d608fa75ba76d6d73daa715abcbdeb9dba02257f05a1b59178b49f599b;
    bytes32 public constant PYTH_XAG_USD_FEED_BASE_MAINNET = 0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e;

    // Gold
    bytes32 public constant PYTH_XAU_USD_FEED_BASE_SEPOLIA = 0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2;
    bytes32 public constant PYTH_XAU_USD_FEED_BASE_GOERLI = 0x30a19158f5a54c0adf8fb7560627343f22a1bc852b89d56be1accdc5dbf96d0e;
    bytes32 public constant PYTH_XAU_USD_FEED_BASE_MAINNET = 0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2;

    bytes32 public constant PYTH_SOL_USD_FEED_BASE_SEPOLIA = 0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d;
    bytes32 public constant PYTH_SOL_USD_FEED_BASE_GOERLI = 0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d;
    bytes32 public constant PYTH_SOL_USD_FEED_BASE_MAINNET = 0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d;

    bytes32 public constant PYTH_BNB_USD_FEED_BASE_SEPOLIA = 0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;
    bytes32 public constant PYTH_BNB_USD_FEED_BASE_GOERLI = 0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;
    bytes32 public constant PYTH_BNB_USD_FEED_BASE_MAINNET = 0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;

    bytes32 public constant PYTH_ARB_USD_FEED_BASE_SEPOLIA = 0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5;
    bytes32 public constant PYTH_ARB_USD_FEED_BASE_GOERLI = 0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5;
    bytes32 public constant PYTH_ARB_USD_FEED_BASE_MAINNET = 0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5;

    bytes32 public constant PYTH_DOGE_USD_FEED_BASE_SEPOLIA = 0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c;
    bytes32 public constant PYTH_DOGE_USD_FEED_BASE_GOERLI = 0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c;
    bytes32 public constant PYTH_DOGE_USD_FEED_BASE_MAINNET = 0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c;

    bytes32 public constant PYTH_AVAX_USD_FEED_BASE_SEPOLIA = 0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7;
    bytes32 public constant PYTH_AVAX_USD_FEED_BASE_GOERLI = 0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7;
    bytes32 public constant PYTH_AVAX_USD_FEED_BASE_MAINNET = 0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7;

    bytes32 public constant PYTH_OP_USD_FEED_BASE_SEPOLIA = 0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf;
    bytes32 public constant PYTH_OP_USD_FEED_BASE_GOERLI = 0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf;
    bytes32 public constant PYTH_OP_USD_FEED_BASE_MAINNET = 0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf;

    bytes32 public constant PYTH_MATIC_USD_FEED_BASE_SEPOLIA = 0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52;
    bytes32 public constant PYTH_MATIC_USD_FEED_BASE_GOERLI = 0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52;
    bytes32 public constant PYTH_MATIC_USD_FEED_BASE_MAINNET = 0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52;

    bytes32 public constant PYTH_TIA_USD_FEED_BASE_SEPOLIA = 0x09f7c1d7dfbb7df2b8fe3d3d87ee94a2259d212da4f30c1f0540d066dfa44723;
    bytes32 public constant PYTH_TIA_USD_FEED_BASE_GOERLI = 0x09f7c1d7dfbb7df2b8fe3d3d87ee94a2259d212da4f30c1f0540d066dfa44723;
    bytes32 public constant PYTH_TIA_USD_FEED_BASE_MAINNET = 0x09f7c1d7dfbb7df2b8fe3d3d87ee94a2259d212da4f30c1f0540d066dfa44723;

    bytes32 public constant PYTH_SEI_USD_FEED_BASE_SEPOLIA = 0x53614f1cb0c031d4af66c04cb9c756234adad0e1cee85303795091499a4084eb;
    bytes32 public constant PYTH_SEI_USD_FEED_BASE_GOERLI = 0x53614f1cb0c031d4af66c04cb9c756234adad0e1cee85303795091499a4084eb;
    bytes32 public constant PYTH_SEI_USD_FEED_BASE_MAINNET = 0x53614f1cb0c031d4af66c04cb9c756234adad0e1cee85303795091499a4084eb;

    //USD/CAD
    bytes32 public constant PYTH_CAD_USD_FEED_BASE_SEPOLIA = 0x3112b03a41c910ed446852aacf67118cb1bec67b2cd0b9a214c58cc0eaa2ecca;
    bytes32 public constant PYTH_CAD_USD_FEED_BASE_GOERLI = 0x3112b03a41c910ed446852aacf67118cb1bec67b2cd0b9a214c58cc0eaa2ecca;
    bytes32 public constant PYTH_CAD_USD_FEED_BASE_MAINNET = 0x3112b03a41c910ed446852aacf67118cb1bec67b2cd0b9a214c58cc0eaa2ecca;

    //USD/CHF
    bytes32 public constant PYTH_CHF_USD_FEED_BASE_SEPOLIA = 0x0b1e3297e69f162877b577b0d6a47a0d63b2392bc8499e6540da4187a63e28f8;
    bytes32 public constant PYTH_CHF_USD_FEED_BASE_GOERLI = 0x0b1e3297e69f162877b577b0d6a47a0d63b2392bc8499e6540da4187a63e28f8;
    bytes32 public constant PYTH_CHF_USD_FEED_BASE_MAINNET = 0x0b1e3297e69f162877b577b0d6a47a0d63b2392bc8499e6540da4187a63e28f8;

    //USD/SEK
    bytes32 public constant PYTH_SEK_USD_FEED_BASE_SEPOLIA = 0x8ccb376aa871517e807358d4e3cf0bc7fe4950474dbe6c9ffc21ef64e43fc676;
    bytes32 public constant PYTH_SEK_USD_FEED_BASE_GOERLI = 0x8ccb376aa871517e807358d4e3cf0bc7fe4950474dbe6c9ffc21ef64e43fc676;
    bytes32 public constant PYTH_SEK_USD_FEED_BASE_MAINNET = 0x8ccb376aa871517e807358d4e3cf0bc7fe4950474dbe6c9ffc21ef64e43fc676;

    bytes32 public constant PYTH_AUD_USD_FEED_BASE_SEPOLIA = 0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80;
    bytes32 public constant PYTH_AUD_USD_FEED_BASE_GOERLI = 0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80;
    bytes32 public constant PYTH_AUD_USD_FEED_BASE_MAINNET = 0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80;

    bytes32 public constant PYTH_NZD_USD_FEED_BASE_SEPOLIA = 0x92eea8ba1b00078cdc2ef6f64f091f262e8c7d0576ee4677572f314ebfafa4c7;
    bytes32 public constant PYTH_NZD_USD_FEED_BASE_GOERLI = 0x92eea8ba1b00078cdc2ef6f64f091f262e8c7d0576ee4677572f314ebfafa4c7;
    bytes32 public constant PYTH_NZD_USD_FEED_BASE_MAINNET = 0x92eea8ba1b00078cdc2ef6f64f091f262e8c7d0576ee4677572f314ebfafa4c7;

    bytes32 public constant PYTH_SGD_USD_FEED_BASE_SEPOLIA = 0x396a969a9c1480fa15ed50bc59149e2c0075a72fe8f458ed941ddec48bdb4918;
    bytes32 public constant PYTH_SGD_USD_FEED_BASE_GOERLI  = 0x396a969a9c1480fa15ed50bc59149e2c0075a72fe8f458ed941ddec48bdb4918;
    bytes32 public constant PYTH_SGD_USD_FEED_BASE_MAINNET = 0x396a969a9c1480fa15ed50bc59149e2c0075a72fe8f458ed941ddec48bdb4918;

/*******************************CHAINLIN FEEDS****************************************************** */

    address public constant ETH_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant ETH_USD_CHAINLINK_FEED_BASE_GOERLI = 0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2;
    address public constant ETH_USD_CHAINLINK_FEED_BASE_MAINNET = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    
    address public constant BTC_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant BTC_USD_CHAINLINK_FEED_BASE_GOERLI = 0xAC15714c08986DACC0379193e22382736796496f;
    address public constant BTC_USD_CHAINLINK_FEED_BASE_MAINNET = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;

    address public constant JPY_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant JPY_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant JPY_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant GBP_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant GBP_USD_CHAINLINK_FEED_BASE_GOERLI = 0x50EcA3DB4DEedcE395F6Ca0D463EE4D4971a60bA;
    address public constant GBP_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant EUR_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant EUR_USD_CHAINLINK_FEED_BASE_GOERLI = 0x619AeaaF08dF3645e138C611bddCaE465312Ef6B;
    address public constant EUR_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant XAG_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant XAG_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant XAG_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant XAU_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant XAU_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant XAU_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant SOL_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant SOL_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant SOL_USD_CHAINLINK_FEED_BASE_MAINNET = 0x975043adBb80fc32276CbF9Bbcfd4A601a12462D;

    address public constant BNB_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant BNB_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant BNB_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant ARB_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant ARB_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant ARB_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant DOGE_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant DOGE_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant DOGE_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant AVAX_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant AVAX_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant AVAX_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant OP_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant OP_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant OP_USD_CHAINLINK_FEED_BASE_MAINNET = 0x3E3A6bD129A63564FE7abde85FA67c3950569060;

    address public constant MATIC_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant MATIC_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant MATIC_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant TIA_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant TIA_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant TIA_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant CAD_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant CAD_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant CAD_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant CHF_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant CHF_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant CHF_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant SEK_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant SEK_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant SEK_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant AUD_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant AUD_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant AUD_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant NZD_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant NZD_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant NZD_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant SGD_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant SGD_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant SGD_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);

    address public constant SEI_USD_CHAINLINK_FEED_BASE_SEPOLIA = address(0);
    address public constant SEI_USD_CHAINLINK_FEED_BASE_GOERLI = address(0);
    address public constant SEI_USD_CHAINLINK_FEED_BASE_MAINNET = address(0);
    
/*******************************TREASURY****************************************************** */

    address public constant BASE_SEPOLIA_GOV_TREASURY = 0x85a6554B36770f6a710b25Cb7d6c251f47974Ac1;
    address public constant BASE_MAINNET_GOV_TREASURY = 0x9176E536F21474502B00e30A5dd24461f7EE6DE1;

    address public constant BASE_SEPOLIA_DEV_TREASURY = 0x9176E536F21474502B00e30A5dd24461f7EE6DE1;
    address public constant BASE_MAINNET_DEV_TREASURY = 0x9176E536F21474502B00e30A5dd24461f7EE6DE1;

    address public constant BASE_SEPOLIA_MARKET_OPERATOR_1 = 0x484AFea81922AaAB0e7d7D9Db3b9fd83Ed1c72c1;
    address public constant BASE_SEPOLIA_MARKET_OPERATOR_2 = 0x63E499f6a1Fe978B3e31f9e75d52814ace9A38DD;
    address public constant BASE_SEPOLIA_MARKET_OPERATOR_3 = 0xE051fb953EC622DD5A910EAC87BbE7b9ceD6a83b;
    address public constant BASE_SEPOLIA_MARKET_OPERATOR_4 = 0xcffc2C7C0151140b7446AB1804350F39dAdF4D69;
    address public constant BASE_SEPOLIA_MARKET_OPERATOR_5 = 0x85075E2BD393Dc32A8Cf70D4b32B3aa926a0fFA4;
    address public constant BASE_SEPOLIA_MARKET_OPERATOR_6 = 0x2045fCb8ADB688bB72bB2b31D5Eb93c9f032aEA1;
    address public constant BASE_SEPOLIA_MARKET_OPERATOR_FEE_RECIEVER = 0x462d2aA3538c235E586853D21fAFFE04e0344120;

    address public constant BASE_MAINNET_MARKET_OPERATOR_1 = 0xdacF6F424E6feAB7Ec556FB5d8Bb28242840ec65;
    address public constant BASE_MAINNET_MARKET_OPERATOR_2 = 0x30C5dD3E5e6a6c02a1bccd4a0Cb52958522445D5;
    address public constant BASE_MAINNET_MARKET_OPERATOR_3 = 0x05E88146Caa54c09eE22d0844780DCEe441EAa38;
    address public constant BASE_MAINNET_MARKET_OPERATOR_4 = 0xdfFD332E0664e3397caDEbcEBe89901622162C3B;
    address public constant BASE_MAINNET_MARKET_OPERATOR_5 = 0xC505d4da24179770515eDD83dDBB8abF3DA88923;
    address public constant BASE_MAINNET_MARKET_OPERATOR_6 = 0x4758844C73EdA5e44aBEdF75aE3D2B1aB2dB6A8b;
    address public constant BASE_MAINNET_MARKET_OPERATOR_FEE_RECIEVER = 0x9176E536F21474502B00e30A5dd24461f7EE6DE1;

    address public constant BASE_MAINNET_PAIR_INFOS_KEEPER = 0x106E9637678fc9D7C673CA25DF61B92B6C4D88ad;
    address public constant BASE_MAINNET_VAULT_KEEPER = 0xfBeb6CDD4e06d142CbbC448Ef2684e98833241AB;
}
