const { ethers } = require("hardhat");

async function main() {
  const [deployer, foundationVault, quantumOracle] = await ethers.getSigners();
  
  console.log("Deploying NexusCore com a conta:", deployer.address);
  console.log("Saldo da conta:", (await deployer.getBalance()).toString());
  
  // Deploy do contrato NexusCore
  const NexusCore = await ethers.getContractFactory("NexusCore");
  const stellarcrucibleAPY = 15;
  const singularityBurnRate = 5;
  
  const nexusCore = await NexusCore.deploy(
    foundationVault.address,
    quantumOracle.address,
    stellarcrucibleAPY,
    singularityBurnRate
  );
  
  await nexusCore.deployed();
  
  console.log("NexusCore deployado em:", nexusCore.address);
  console.log("Foundation Vault:", foundationVault.address);
  console.log("Quantum Oracle:", quantumOracle.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });