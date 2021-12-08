// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IOracle.sol";
import "./interfaces/ITokenBar.sol";

/// @title TokenBar is the place where you can exercise your rights to buy liquidity mined tokens
// solhint-disable not-rely-on-time
contract TokenBar is
  Ownable,
  ReentrancyGuard,
  ITokenBar,
  ERC721("Token Option", "TKNBAR")
{
  /// @dev events
  event LogOptionCreated(
    uint256 indexed _optionId,
    address indexed _owner,
    uint256 _amount,
    uint256 _price,
    uint256 _expiry
  );
  event LogOptionExcersied(
    uint256 indexed _optionId,
    address indexed _caller,
    uint256 _amount,
    uint256 _price,
    uint256 _expiry
  );
  event LogSetGov(address _prevGov, address _newGov);
  event LogSetDiscount(uint256 _prevDiscount, uint256 _newDiscount);

  /// @dev structs
  struct OptionInfo {
    uint256 amount;
    uint256 price;
    uint256 expiry;
    bool exercised;
  }

  /// @dev configurable states
  address public gov;
  IERC20 public token;
  IOracle public oracle;
  bytes public oracleData;
  uint256 public optionExpiry;
  uint64 public discountFactor;

  /// @dev states
  uint256 public nextID;
  OptionInfo[] public options;

  constructor(
    address _gov,
    IERC20 _token,
    IOracle _oracle,
    bytes memory _oracleData,
    uint256 _optionExpiry,
    uint64 _discountFactor
  ) {
    require(_gov != address(0), "bad gov");
    require(address(_token) != address(0), "bad token");
    require(address(_oracle) != address(0), "bad oracle");

    gov = _gov;
    token = _token;
    oracle = _oracle;
    oracleData = _oracleData;
    optionExpiry = _optionExpiry;
    discountFactor = _discountFactor;

    // sanity call to make sure oracle is correct
    oracle.get(_oracleData);
  }

  modifier onlyGov() {
    require(msg.sender == gov, "only gov");
    _;
  }

  function exercise(uint256 _optionId) external payable nonReentrant {
    OptionInfo storage _option = options[_optionId];

    require(block.timestamp >= _option.expiry, "!expired");
    require(_option.exercised == false, "already exercised");
    require(_option.price == msg.value, "bad value");

    // 1. Transfer option from msg.sender
    transferFrom(msg.sender, address(this), _optionId);
    _burn(_optionId);

    // 2. Mark option as exercised
    options[_optionId].exercised = true;

    // 3. Transfer token to msg.sender
    token.transfer(msg.sender, options[_optionId].amount);

    emit LogOptionExcersied(
      _optionId,
      msg.sender,
      _option.amount,
      _option.price,
      _option.expiry
    );
  }

  function _mintOption(address _to, uint256 _amount)
    internal
    returns (uint256)
  {
    (bool _update, uint256 _price) = oracle.get(oracleData);
    require(_update, "!update");
    uint256 _expiry = block.timestamp + optionExpiry;
    options.push(
      OptionInfo({
        amount: _amount,
        price: (_price * discountFactor) / 1e4,
        expiry: _expiry,
        exercised: false
      })
    );
    _safeMint(_to, nextID);
    emit LogOptionCreated(nextID, _to, _amount, _price, _expiry);
    return nextID++;
  }

  function mintOption(address _to, uint256 _amount)
    external
    nonReentrant
    onlyOwner
  {
    if (_amount > 0) {
      _mintOption(_to, _amount);
    }
  }

  function setGov(address _newGov) external onlyGov {
    require(_newGov != address(0), "!zero");

    address _prevGov = gov;
    gov = _newGov;

    emit LogSetGov(_prevGov, _newGov);
  }

  function setDiscountBps(uint64 _newDiscountFactor) external onlyGov {
    require(
      _newDiscountFactor >= 1000 && _newDiscountFactor <= 3000,
      "!in range"
    );

    uint64 _prevDiscountBps = discountFactor;
    discountFactor = _newDiscountFactor;

    emit LogSetDiscount(_prevDiscountBps, _newDiscountFactor);
  }

  function withdraw(address payable _to) external onlyGov {
    require(_to != address(0), "!zero");
    _to.transfer(address(this).balance);
  }
}
