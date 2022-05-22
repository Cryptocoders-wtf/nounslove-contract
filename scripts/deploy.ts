// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // https://etherscan.io/address/0x9c8ff314c9bc7f6e59a9d9225fb22946427edc03#code

  /*
  const Greeter = await ethers.getContractFactory("Greeter");
  const greeter = await Greeter.deploy("hello");

  await greeter.deployed();
  */

  const minter = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
  const descriptor = "0x0cfdb3ba1694c2bb2cfacb0339ad7b1ae5932b63";
  const seeder = "0xcc8a0fb5ab3c7132c1b2a0109142fb112c4ce515";
  const proxy = "0xa5409ec958c83c3f309868babaca7c86dcb077c1";
  
  const developpers = [
    "0x818Fb9d440968dB9fCB06EEF53C7734Ad70f6F0e", // ai
    "0x4F1CA5Ac1ab5e119b2C8F015cDC53e618ae9559a", // art fes
  ];
  // await deployer.deploy(NFT, minter, descriptor, seeder, developpers, proxy);

  // 1 eth = 10**18
  const priceSeed = {
    maxPrice:  String(10 ** 18), // 1 ether;
    minPrice:  String(5 * 10 ** 15), //  0.005 ether; = 5 * 10^-3
    priceDelta:  String(15 * 10 ** 15), // 0.015 ether; = 15 * 10^-2
    timeDelta: 60, // 1 minutes; 
    expirationTime: 90 * 60, // 90 minutes;
  };
  
  // We get the contract to deploy
  const NounsToken = await ethers.getContractFactory("NounsToken");
  const nounsToken = await NounsToken.deploy(minter, descriptor, seeder, developpers, priceSeed, proxy);

  await nounsToken.deployed();

  
  console.log("nounsToken deployed to:", nounsToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
