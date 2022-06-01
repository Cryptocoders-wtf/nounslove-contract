import { ethers } from "hardhat";

async function main() {
  const nounsToken = "0xa722bdA6968F50778B973Ae2701e90200C564B49";
  const priceSeed = {
    maxPrice:  String(10 ** 18), // 1 ether;
    minPrice:  String(5 * 10 ** 15), //  0.005 ether; = 5 * 10^-3
    priceDelta:  String(15 * 10 ** 15), // 0.015 ether; = 15 * 10^-2
    timeDelta: 60, // 1 minutes; 
    expirationTime: 90 * 60, // 90 minutes;
  };

  // We get the contract to deploy
  const NounsToken = await ethers.getContractFactory("NounsToken");
  const descriptorContract = NounsToken.attach(nounsToken);

  await descriptorContract.setPriceData(priceSeed);

  const data = await descriptorContract.getPriceData();
  console.log(data);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
