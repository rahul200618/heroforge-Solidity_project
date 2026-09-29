// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./HeroForgeStorage.sol";

/**
 * @title  HeroForgeCharacters
 * @notice Handles character NFT minting and character data reads.
 *         Inherits all state and access control from HeroForgeStorage.
 *         Abstract: not deployed directly.
 */
abstract contract HeroForgeCharacters is HeroForgeStorage {

    /**
     * @notice Mint a new character NFT to the caller.
     *         Anyone can call this — no role restriction.
     *         Base stats: strength 1, speed 1, defence 1, XP 0.
     *
     * @param  name    Display name for the character.
     * @return tokenId The newly minted character's token ID.
     */
    function mintCharacter(string calldata name)
        external
        returns (uint256)
    {
        _charCounter++;
        uint256 tokenId = _charCounter;

        // Effects — write all state before any external call (CEI)
        isCharacter[tokenId]  = true;
        characters[tokenId]   = Character({
            name:     name,
            xp:       0,
            strength: BASE_STAT,
            speed:    BASE_STAT,
            defence:  BASE_STAT
        });

        // Interactions — _safeMint is an external call, so it goes last
        _safeMint(msg.sender, tokenId);

        emit CharacterMinted(tokenId, msg.sender, name);
        return tokenId;
    }

    /**
     * @notice Return the full Character struct for a given token ID.
     * @param  charId Token ID of the character.
     */
    function getCharacter(uint256 charId)
        external
        view
        returns (Character memory)
    {
        if (!isCharacter[charId]) revert NotACharacter();
        return characters[charId];
    }
}
