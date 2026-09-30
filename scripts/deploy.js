/**
 * HeroForge Deploy Script
 * ─────────────────────────────────────────────────────────────────────────────
 * Usage:
 *   npx hardhat run scripts/deploy.js --network sepolia
 *
 * Required .env variables:
 *   PRIVATE_KEY          — deployer wallet private key
 *   SEPOLIA_RPC_URL      — Alchemy / Infura Sepolia endpoint
 *   ETHERSCAN_API_KEY    — for automatic source verification
 *   GAME_MASTER_ADDRESS  — wallet authorised to mint items and grant XP
 *                          (defaults to deployer address if not set)
 */

const { ethers, run } = require("hardhat");
require("dotenv").config();

async function main() {
  // ─── Signers & config ────────────────────────────────────────────────────
  const [deployer] = await ethers.getSigners();
  const gameMaster = process.env.GAME_MASTER_ADDRESS || deployer.address;

  console.log("─────────────────────────────────────────");
  console.log("  HeroForge — Deployment");
  console.log("─────────────────────────────────────────");
  console.log("  Deployer    :", deployer.address);
  console.log("  Game Master :", gameMaster);
  console.log("  Network     :", (await ethers.provider.getNetwork()).name);
  console.log("─────────────────────────────────────────\n");

  // ─── Deploy ───────────────────────────────────────────────────────────────
  console.log("Deploying HeroForge...");
  const HeroForge = await ethers.getContractFactory("contracts/HeroForgeCombined.sol:HeroForge"); const heroforge = await HeroForge.deploy(gameMaster);
  await heroforge.waitForDeployment();

  const address = await heroforge.getAddress();
  console.log("✓ HeroForge deployed to:", address);

  // ─── Wait for confirmations ───────────────────────────────────────────────
  console.log("\nWaiting for 5 block confirmations before verifying...");
  await heroforge.deploymentTransaction().wait(5);
  console.log("✓ Confirmations received");

  // ─── Verify ───────────────────────────────────────────────────────────────
  console.log("\nVerifying contract on Etherscan...");
  try {
    await run("verify:verify", {
      address: address,
      constructorArguments: [gameMaster],
      contract: "contracts/HeroForgeCombined.sol:HeroForge",
    });
    console.log("✓ Contract verified on Etherscan");
  } catch (err) {
    if (err.message.toLowerCase().includes("already verified")) {
      console.log("✓ Contract already verified");
    } else {
      console.error("✗ Verification failed:", err.message);
      console.log("  Run manually:");
      console.log(`  npx hardhat verify --network sepolia ${address} "${gameMaster}"`);
    }
  }

  // ─── Summary ──────────────────────────────────────────────────────────────
  console.log("\n─────────────────────────────────────────");
  console.log("  Deployment Complete");
  console.log("─────────────────────────────────────────");
  console.log("  Contract :", address);
  console.log("  Explorer : https://sepolia.etherscan.io/address/" + address);
  console.log("\n  Demonstration sequence:");
  console.log("  1. mintCharacter('YourName')");
  console.log("  2. mintItem(playerAddress, 'sword')       ← game master");
  console.log("  3. equipItem(charId, itemId)");
  console.log("  4. earnXP(charId, 10)                     ← game master");
  console.log("  5. spendXP(charId, 'strength')");
  console.log("  6. transferFrom(...)                       ← reverts (equipped)");
  console.log("  7. unequipItem(charId, itemId)");
  console.log("  8. transferFrom(...)                       ← succeeds");
  console.log("─────────────────────────────────────────\n");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
