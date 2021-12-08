// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.10;

interface IOracle {
  function get(bytes calldata _oracleData)
    external
    view
    returns (bool success, uint256 rate);
}
