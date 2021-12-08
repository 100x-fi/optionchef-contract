// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20("TOKEN", "TKN"), Ownable {
  /// @dev events
  event LogSetMinterOk(address _caller, address _minter, bool _ok);

  /// @dev states
  mapping(address => bool) public minters;

  modifier onlyMinter() {
    require(minters[msg.sender] == true, "only minter");
    _;
  }

  function mint(address _to, uint256 _amount) external onlyMinter {
    _mint(_to, _amount);
  }

  function setMinterOk(address[] calldata _minters, bool[] calldata _ok)
    external
    onlyOwner
  {
    require(_minters.length == _ok.length, "bad len");
    for (uint256 i = 0; i < _minters.length; i++) {
      minters[_minters[i]] = _ok[i];
      emit LogSetMinterOk(msg.sender, _minters[i], _ok[i]);
    }
  }
}
