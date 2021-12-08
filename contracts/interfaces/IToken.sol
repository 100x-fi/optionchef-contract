// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.10;

interface IToken {
  function mint(address _to, uint256 _amount) external;
}
