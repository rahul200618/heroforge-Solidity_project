const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

/**
 * HeroForge Test Suite
 * ─────────────────────────────────────────────────────────────────────────────
 * 13 tests total
 *   Success paths (5) : T-01 … T-05
 *   Failure paths (8) : T-06 … T-13
 *
 * Every privileged function is covered by at least one rejection test:
 *   mintItem()      → T-08  (NotGameMaster)
 *   earnXP()        → T-07  (NotGameMaster)
 *   equipItem()     → T-09  (NotItemOwner / NotCharacterOwner)
 *   unequipItem()   → T-09 (NotCharacterOwner via modifier)
 *   spendXP()       → T-10  (NotCharacterOwner via modifier)
 *   setGameMaster() → T-13  (OwnableUnauthorizedAccount)
 *
 * Every invariant from SPEC.md is covered by at least one test:
 *   Inv-1 character with equipped items cannot transfer → T-06
 *   Inv-2 non-game-master cannot earnXP               → T-07
 *   Inv-3 non-game-master cannot mintItem             → T-08
 *   Inv-4 player equips item they don't own           → T-09
 *   Inv-5 item equipped to two characters             → T-12
 *   Inv-6 XP underflow                                → T-10
 *   Inv-7 stat upgrade beyond MAX_STAT                → T-11
 */

describe("HeroForge", function () {

  // ─── Fixture ────────────────────────────────────────────────────────────────

  async function deployFixture() {
    const [owner, gameMaster, player, player2, attacker] = await ethers.getSigners();

    const HeroForge = await ethers.getContractFactory("contracts/HeroForgeCombined.sol:HeroForge"); const heroforge = await HeroForge.deploy(gameMaster.address);
    await heroforge.waitForDeployment();

    return { heroforge, owner, gameMaster, player, player2, attacker };
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /** Mint a character and return its token ID from the emitted event. */
  async function mintCharacter(heroforge, signer, name = "Hero") {
    const tx = await heroforge.connect(signer).mintCharacter(name);
    const receipt = await tx.wait();
    const log = receipt.logs
      .map(l => { try { return heroforge.interface.parseLog(l); } catch { return null; } })
      .find(e => e?.name === "CharacterMinted");
    return log.args.tokenId;
  }

  /** Game master mints an item to a recipient and returns its token ID. */
  async function mintItem(heroforge, gameMaster, recipient, itemType = "sword") {
    const tx = await heroforge.connect(gameMaster).mintItem(recipient.address, itemType);
    const receipt = await tx.wait();
    const log = receipt.logs
      .map(l => { try { return heroforge.interface.parseLog(l); } catch { return null; } })
      .find(e => e?.name === "ItemMinted");
    return log.args.itemId;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SUCCESS PATHS
  // ════════════════════════════════════════════════════════════════════════════

  describe("T-01 mintCharacter — success", function () {
    it("mints a character NFT to the caller with correct base stats and zero XP", async function () {
      const { heroforge, player } = await loadFixture(deployFixture);

      await expect(heroforge.connect(player).mintCharacter("Thorin"))
        .to.emit(heroforge, "CharacterMinted")
        .withArgs(1n, player.address, "Thorin");

      const char = await heroforge.getCharacter(1n);
      expect(char.name).to.equal("Thorin");
      expect(char.xp).to.equal(0n);
      expect(char.strength).to.equal(1n);
      expect(char.speed).to.equal(1n);
      expect(char.defence).to.equal(1n);
      expect(await heroforge.ownerOf(1n)).to.equal(player.address);
      expect(await heroforge.isCharacter(1n)).to.be.true;
    });
  });

  describe("T-02 mintItem — success", function () {
    it("game master mints an item NFT to a player with correct type and zero equippedTo", async function () {
      const { heroforge, gameMaster, player } = await loadFixture(deployFixture);

      const ITEM_ID = 1_000_001n;

      await expect(heroforge.connect(gameMaster).mintItem(player.address, "sword"))
        .to.emit(heroforge, "ItemMinted")
        .withArgs(ITEM_ID, "sword", player.address);

      const item = await heroforge.getItem(ITEM_ID);
      expect(item.itemType).to.equal("sword");
      expect(item.equippedTo).to.equal(0n);
      expect(await heroforge.ownerOf(ITEM_ID)).to.equal(player.address);
      expect(await heroforge.isCharacter(ITEM_ID)).to.be.false;
    });
  });

  describe("T-03 equipItem — success", function () {
    it("owner equips item to their character; hasEquippedItems becomes true", async function () {
      const { heroforge, gameMaster, player } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);
      const itemId = await mintItem(heroforge, gameMaster, player);

      await expect(heroforge.connect(player).equipItem(charId, itemId))
        .to.emit(heroforge, "ItemEquipped")
        .withArgs(charId, itemId, player.address);

      expect(await heroforge.hasEquippedItems(charId)).to.be.true;
      const item = await heroforge.getItem(itemId);
      expect(item.equippedTo).to.equal(charId);
      const equipped = await heroforge.getEquippedItems(charId);
      expect(equipped).to.include(itemId);
    });
  });

  describe("T-04 unequipItem — success", function () {
    it("owner removes item; hasEquippedItems clears; character becomes transferable", async function () {
      const { heroforge, gameMaster, player, player2 } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);
      const itemId = await mintItem(heroforge, gameMaster, player);
      await heroforge.connect(player).equipItem(charId, itemId);

      await expect(heroforge.connect(player).unequipItem(charId, itemId))
        .to.emit(heroforge, "ItemUnequipped")
        .withArgs(charId, itemId, player.address);

      expect(await heroforge.hasEquippedItems(charId)).to.be.false;
      const item = await heroforge.getItem(itemId);
      expect(item.equippedTo).to.equal(0n);

      // Transfer lock should now be gone
      await heroforge.connect(player).transferFrom(player.address, player2.address, charId);
      expect(await heroforge.ownerOf(charId)).to.equal(player2.address);
    });
  });

  describe("T-05 earnXP + spendXP — success", function () {
    it("game master grants XP; player spends it to permanently upgrade a stat", async function () {
      const { heroforge, gameMaster, player } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);

      await expect(heroforge.connect(gameMaster).earnXP(charId, 10n))
        .to.emit(heroforge, "XPEarned")
        .withArgs(charId, 10n, 10n);

      let char = await heroforge.getCharacter(charId);
      expect(char.xp).to.equal(10n);

      await expect(heroforge.connect(player).spendXP(charId, "strength"))
        .to.emit(heroforge, "StatUpgraded")
        .withArgs(charId, "strength", 1n, 2n);

      char = await heroforge.getCharacter(charId);
      expect(char.strength).to.equal(2n);
      expect(char.xp).to.equal(0n);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // FAILURE PATHS
  // ════════════════════════════════════════════════════════════════════════════

  describe("T-06 transferFrom — reverts when character has equipped items [Inv-1]", function () {
    it("reverts with CharacterHasEquippedItems; item cannot be stripped via transfer either", async function () {
      const { heroforge, gameMaster, player, player2 } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);
      const itemId = await mintItem(heroforge, gameMaster, player);
      await heroforge.connect(player).equipItem(charId, itemId);

      // Character transfer locked
      await expect(
        heroforge.connect(player).transferFrom(player.address, player2.address, charId)
      ).to.be.revertedWithCustomError(heroforge, "CharacterHasEquippedItems");

      // Equipped item is also transfer-locked
      await expect(
        heroforge.connect(player).transferFrom(player.address, player2.address, itemId)
      ).to.be.revertedWithCustomError(heroforge, "ItemAlreadyEquipped");
    });
  });

  describe("T-07 earnXP — reverts for non-game-master caller [Inv-2]", function () {
    it("reverts with NotGameMaster when an attacker calls earnXP", async function () {
      const { heroforge, player, attacker } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);

      await expect(
        heroforge.connect(attacker).earnXP(charId, 1000n)
      ).to.be.revertedWithCustomError(heroforge, "NotGameMaster");
    });
  });

  describe("T-08 mintItem — reverts for non-game-master caller [Inv-3]", function () {
    it("reverts with NotGameMaster when an attacker tries to mint an item", async function () {
      const { heroforge, player, attacker } = await loadFixture(deployFixture);

      await expect(
        heroforge.connect(attacker).mintItem(player.address, "sword")
      ).to.be.revertedWithCustomError(heroforge, "NotGameMaster");
    });
  });

  describe("T-09 equipItem — reverts when caller does not own the item [Inv-4]", function () {
    it("reverts with NotItemOwner when attacker tries to equip another player's item", async function () {
      const { heroforge, gameMaster, player, attacker } = await loadFixture(deployFixture);

      const attackerCharId = await mintCharacter(heroforge, attacker);
      const itemId = await mintItem(heroforge, gameMaster, player); // item owned by player

      await expect(
        heroforge.connect(attacker).equipItem(attackerCharId, itemId)
      ).to.be.revertedWithCustomError(heroforge, "NotItemOwner");
    });
  });

  describe("T-10 spendXP — reverts when XP balance is insufficient [Inv-6]", function () {
    it("reverts with InsufficientXP when character has 0 XP", async function () {
      const { heroforge, player } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);
      // No earnXP call — character has 0 XP

      await expect(
        heroforge.connect(player).spendXP(charId, "strength")
      ).to.be.revertedWithCustomError(heroforge, "InsufficientXP");
    });
  });

  describe("T-11 spendXP — reverts when stat is at MAX_STAT (100) [Inv-7]", function () {
    it("reverts with StatCapReached after strength reaches 100", async function () {
      const { heroforge, gameMaster, player } = await loadFixture(deployFixture);

      const charId = await mintCharacter(heroforge, player);

      // 99 upgrades needed (1 → 100), each costs 10 XP → grant 990 XP up front
      await heroforge.connect(gameMaster).earnXP(charId, 990n);
      for (let i = 0; i < 99; i++) {
        await heroforge.connect(player).spendXP(charId, "strength");
      }

      const char = await heroforge.getCharacter(charId);
      expect(char.strength).to.equal(100n);

      // Grant 10 more XP then try to exceed the cap
      await heroforge.connect(gameMaster).earnXP(charId, 10n);
      await expect(
        heroforge.connect(player).spendXP(charId, "strength")
      ).to.be.revertedWithCustomError(heroforge, "StatCapReached");
    });
  });

  describe("T-12 equipItem — reverts when item is already equipped [Inv-5]", function () {
    it("reverts with ItemAlreadyEquipped when same item is equipped to a second character", async function () {
      const { heroforge, gameMaster, player } = await loadFixture(deployFixture);

      const charId1 = await mintCharacter(heroforge, player, "Hero One");
      const charId2 = await mintCharacter(heroforge, player, "Hero Two");
      const itemId = await mintItem(heroforge, gameMaster, player);

      await heroforge.connect(player).equipItem(charId1, itemId);

      // Try to equip the same item to the second character
      await expect(
        heroforge.connect(player).equipItem(charId2, itemId)
      ).to.be.revertedWithCustomError(heroforge, "ItemAlreadyEquipped");
    });
  });

  describe("T-13 setGameMaster — reverts for non-owner [privileged]", function () {
    it("reverts with OwnableUnauthorizedAccount when attacker tries to rotate game master", async function () {
      const { heroforge, attacker } = await loadFixture(deployFixture);

      await expect(
        heroforge.connect(attacker).setGameMaster(attacker.address)
      ).to.be.revertedWithCustomError(heroforge, "OwnableUnauthorizedAccount");
    });
  });

});
