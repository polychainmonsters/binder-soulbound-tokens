// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.20;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract Soulbound is ERC721, ERC721Burnable, Ownable {
//     uint256 private _nextTokenId;

//     constructor(
//         address initialOwner
//     ) ERC721("Soulbound", "Soulbound") Ownable(initialOwner) {}

//     function safeMint(address to) public onlyOwner {
//         uint256 tokenId = _nextTokenId++;
//         _safeMint(to, tokenId);
//     }
// }
