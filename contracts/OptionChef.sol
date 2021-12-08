// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IToken.sol";
import "./interfaces/ITokenBar.sol";

contract OptionChef is Ownable {
  using SafeERC20 for IERC20;

  /// @dev events
  event LogDeposit(address indexed user, uint256 indexed pid, uint256 amount);
  event LogWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event LogEmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );
  event LogSetTreasury(
    address indexed _prevTreasury,
    address indexed _newTreasury
  );

  /// @dev structs
  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
  }

  struct PoolInfo {
    IERC20 stakeToken;
    uint256 allocPoint;
    uint256 lastRewardBlock;
    uint256 accTknPerShare;
  }

  /// @dev configurable states
  IToken public token;
  ITokenBar public tokenBar;
  address public treasury;
  uint256 public tokenPerBlock;
  uint256 public startBlock;
  mapping(address => bool) public isPoolAdded;

  /// @dev run-time states
  PoolInfo[] public poolInfo;
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  uint256 public totalAllocPoint = 0;

  constructor(
    IToken _token,
    ITokenBar _tokenBar,
    address _treasury,
    uint256 _tokenPerBlock,
    uint256 _startBlock
  ) {
    token = _token;
    tokenBar = _tokenBar;
    treasury = _treasury;
    tokenPerBlock = _tokenPerBlock;
    startBlock = _startBlock;
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  /// @notice Add a new pool
  /// @param _allocPoint The allocation point of the pool
  /// @param _stakeToken The token contract of the pool
  /// @param _withUpdate The flag to update all pools
  function addPool(
    uint256 _allocPoint,
    IERC20 _stakeToken,
    bool _withUpdate
  ) public onlyOwner {
    require(isPoolAdded[address(_stakeToken)] == false, "dup pool");

    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 lastRewardBlock = block.number > startBlock
      ? block.number
      : startBlock;
    totalAllocPoint = totalAllocPoint + _allocPoint;
    poolInfo.push(
      PoolInfo({
        stakeToken: _stakeToken,
        allocPoint: _allocPoint,
        lastRewardBlock: lastRewardBlock,
        accTknPerShare: 0
      })
    );
    isPoolAdded[address(_stakeToken)] = true;
  }

  /// @notice Update the given pool's allocation point. Can only be called by the owner.
  /// @param _pid The pool ID
  /// @param _allocPoint The new allocation point
  /// @param _withUpdate The flag to update all pools
  function setPool(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
    poolInfo[_pid].allocPoint = _allocPoint;
  }

  /// @notice Return reward multiplier over the given _from to _to block.
  function getMultiplier(uint256 _from, uint256 _to)
    public
    pure
    returns (uint256)
  {
    return _to - _from;
  }

  /// @notice View function to see pending TKNs.
  /// @dev pending TKNs = # of TKNs that users will get if exercise the option
  /// @param _pid The pool ID
  /// @param _user The user address
  function pendingTkn(uint256 _pid, address _user)
    external
    view
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accTknPerShare = pool.accTknPerShare;
    uint256 lpSupply = pool.stakeToken.balanceOf(address(this));
    if (block.number > pool.lastRewardBlock && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
      uint256 reward = (multiplier * tokenPerBlock * pool.allocPoint) /
        totalAllocPoint;
      accTknPerShare = accTknPerShare + ((reward * 1e12) / lpSupply);
    }
    return ((user.amount * accTknPerShare) / 1e12) - user.rewardDebt;
  }

  /// @notice Update reward vairables for all pools.
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  /// @notice Update reward variables of the given pool to be up-to-date.
  /// @param _pid The pool ID to be updated
  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.number <= pool.lastRewardBlock) {
      return;
    }
    uint256 lpSupply = pool.stakeToken.balanceOf(address(this));
    if (lpSupply == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
    uint256 reward = (multiplier * tokenPerBlock * pool.allocPoint) /
      totalAllocPoint;
    token.mint(treasury, reward / 10);
    token.mint(address(tokenBar), reward);
    pool.accTknPerShare = pool.accTknPerShare + ((reward * 1e12) / lpSupply);
    pool.lastRewardBlock = block.number;
  }

  /// @notice Deposit tokens to the given pool.
  /// @param _pid The pool ID
  /// @param _amount The amount of tokens to deposit
  function deposit(uint256 _pid, uint256 _amount) external {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (user.amount > 0) {
      uint256 pending = ((user.amount * pool.accTknPerShare) / 1e12) -
        user.rewardDebt;
      tokenBar.mintOption(msg.sender, pending);
    }
    pool.stakeToken.safeTransferFrom(
      address(msg.sender),
      address(this),
      _amount
    );
    user.amount = user.amount + _amount;
    user.rewardDebt = (user.amount * pool.accTknPerShare) / 1e12;
    emit LogDeposit(msg.sender, _pid, _amount);
  }

  /// @notice Withdraw tokens from the given pool.
  /// @param _pid The pool ID
  /// @param _amount The amount of tokens to withdraw
  function withdraw(uint256 _pid, uint256 _amount) external {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "withdraw: not good");
    updatePool(_pid);
    uint256 pending = ((user.amount * pool.accTknPerShare) / 1e12) -
      user.rewardDebt;
    tokenBar.mintOption(msg.sender, pending);
    user.amount = user.amount - _amount;
    user.rewardDebt = (user.amount * pool.accTknPerShare) / 1e12;
    pool.stakeToken.safeTransfer(address(msg.sender), _amount);
    emit LogWithdraw(msg.sender, _pid, _amount);
  }

  /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
  /// @param _pid The pool ID to be withdrawn
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    pool.stakeToken.safeTransfer(address(msg.sender), user.amount);
    emit LogEmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  /// @notice Set a new treausry
  /// @param _newTreasury The new treasury address
  function setTreasury(address _newTreasury) external {
    require(msg.sender == treasury, "!treasury");

    address _prevTreasury = treasury;
    treasury = _newTreasury;

    emit LogSetTreasury(_prevTreasury, _newTreasury);
  }
}
