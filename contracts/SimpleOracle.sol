// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOracle.sol";

contract SimpleOracle is Ownable, IOracle {
  uint256 private _price;

  function get(
    bytes calldata /* _oracleData */
  ) external view override returns (bool, uint256) {
    return (true, _price);
  }

  function set(uint256 _newPrice) external onlyOwner {
    require(_newPrice > 0, "bad new price");
    _price = _newPrice;
  }
}
