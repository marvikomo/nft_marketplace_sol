/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-waffle");
 require("@nomiclabs/hardhat-ethers");
 const fs = require('fs')
 //const privateKey = fs.readFileSync('.secrete').toString()
 const RINKEBY_RPC_URL = "https://rinkeby.infura.io/v3/b4074d04e5e947208fa8b8b601ee57bf";
const PRIVATE_KEY = "d5b8d86ebbadacd0ab095a3f620963268a7fd5c48d9819e7956d95f44d360e6f";
module.exports = {
  networks:{
    hardhat:{
        chainId: 1377
      },
      mumbai:{
        url:RINKEBY_RPC_URL,
        accounts:[PRIVATE_KEY]
      },
      mainnet:{
        url:"https://polygon-mainnet.infura.io/v3/33de597949e847ecbea3575de71646ba",
        accounts:[]
      }
    },

  solidity:{
    compilers: [
      {
        version: "0.8.0",
      },
      {
        version: "0.8.7",
        settings: {},
      },
    ],
  }
};
//0xd70e0c161B053114705f212a593f13B97b3fbb7f