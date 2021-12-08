import { Signer } from "@ethersproject/abstract-signer";
import { BigNumber } from "@ethersproject/bignumber";
import { waffle, ethers } from "hardhat";
import {
  OptionChef,
  OptionChef__factory,
  SimpleOracle,
  SimpleOracle__factory,
  Token,
  TokenBar,
  TokenBar__factory,
  Token__factory,
} from "../typechain";
import chai from "chai";
import * as timeHelpers from "./helpers/time";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
const { expect } = chai;

describe("OptionChef", () => {
  /// constants
  const TKN_PER_BLOCK = ethers.utils.parseUnits("100", 18);
  const START_BLOCK = "0";
  const OPTION_EXIPRY = timeHelpers.WEEK;
  const DISCOUNT_FACTOR = ethers.BigNumber.from("9500");
  const TKN_PRICE = ethers.utils.parseUnits("1", 18);

  /// signers
  let deployer: Signer;
  let alice: Signer;
  let bob: Signer;

  let deployerAddress: string;
  let aliceAddress: string;
  let bobAddress: string;

  /// contract instances
  let simpleOracle: SimpleOracle;
  let stakeToken: Token;
  let token: Token;
  let tokenBar: TokenBar;
  let optionChef: OptionChef;

  /// contract with signer
  let tokenAsAlice: Token;
  let stakeTokenAsAlice: Token;
  let tokenBarAsAlice: TokenBar;
  let optionChefAsAlice: OptionChef;

  let tokenAsBob: Token;
  let stakeTokenAsBob: Token;
  let tokenBarAsBob: TokenBar;
  let optionChefAsBob: OptionChef;

  async function fixture() {
    [deployer, alice, bob] = await ethers.getSigners();
    [deployerAddress, aliceAddress, bobAddress] = await Promise.all([
      deployer.getAddress(),
      alice.getAddress(),
      bob.getAddress(),
    ]);

    const SimpleOracle = (await ethers.getContractFactory(
      "SimpleOracle"
    )) as SimpleOracle__factory;
    simpleOracle = await SimpleOracle.deploy();

    const Token = (await ethers.getContractFactory("Token")) as Token__factory;
    token = await Token.deploy();
    stakeToken = await Token.deploy();

    // allow deployer to mint
    await stakeToken.setMinterOk([deployerAddress], [true]);

    // mint TKN
    await stakeToken.mint(deployerAddress, ethers.utils.parseEther("1000000"));
    await stakeToken.mint(aliceAddress, ethers.utils.parseEther("1000000"));
    await stakeToken.mint(bobAddress, ethers.utils.parseEther("1000000"));

    const TokenBar = (await ethers.getContractFactory(
      "TokenBar"
    )) as TokenBar__factory;
    tokenBar = await TokenBar.deploy(
      deployerAddress,
      token.address,
      simpleOracle.address,
      "0x",
      OPTION_EXIPRY,
      DISCOUNT_FACTOR
    );

    const OptionChef = (await ethers.getContractFactory(
      "OptionChef"
    )) as OptionChef__factory;
    optionChef = await OptionChef.deploy(
      token.address,
      tokenBar.address,
      deployerAddress,
      TKN_PER_BLOCK,
      START_BLOCK
    );

    await token.setMinterOk([optionChef.address], [true]);
    await tokenBar.transferOwnership(optionChef.address);

    // Set oracle price
    await simpleOracle.set(TKN_PRICE);

    tokenAsAlice = Token__factory.connect(token.address, alice);
    stakeTokenAsAlice = Token__factory.connect(stakeToken.address, alice);
    tokenBarAsAlice = TokenBar__factory.connect(tokenBar.address, alice);
    optionChefAsAlice = OptionChef__factory.connect(optionChef.address, alice);

    await stakeTokenAsAlice.approve(
      optionChef.address,
      ethers.constants.MaxUint256
    );

    tokenAsBob = Token__factory.connect(token.address, bob);
    stakeTokenAsBob = Token__factory.connect(stakeToken.address, bob);
    tokenBarAsBob = TokenBar__factory.connect(tokenBar.address, bob);
    optionChefAsBob = OptionChef__factory.connect(optionChef.address, bob);

    await stakeTokenAsBob.approve(
      optionChef.address,
      ethers.constants.MaxUint256
    );
  }

  beforeEach(async () => {
    await waffle.loadFixture(fixture);
  });

  describe("#addPool", async () => {
    context("when add duplicated pool", async () => {
      it("should revert", async () => {
        expect(await optionChef.isPoolAdded(stakeToken.address)).to.be.eq(
          false
        );

        await optionChef.addPool(100, stakeToken.address, true);

        const poolInfo = await optionChef.poolInfo(0);
        expect(poolInfo.stakeToken).to.equal(stakeToken.address);
        expect(poolInfo.allocPoint).to.equal(100);
        expect(await optionChef.isPoolAdded(stakeToken.address)).to.equal(true);

        await expect(
          optionChef.addPool(100, stakeToken.address, true)
        ).to.be.revertedWith("dup pool");
      });
    });

    context("when add valid pool", async () => {
      it("should work", async () => {
        expect(await optionChef.isPoolAdded(stakeToken.address)).to.be.eq(
          false
        );

        await optionChef.addPool(100, stakeToken.address, true);

        const poolInfo = await optionChef.poolInfo(0);
        expect(poolInfo.stakeToken).to.equal(stakeToken.address);
        expect(poolInfo.allocPoint).to.equal(100);
        expect(await optionChef.isPoolAdded(stakeToken.address)).to.equal(true);
      });
    });
  });

  describe("#complex", async () => {
    it("should work", async () => {
      // Prepare variables
      let aliceTknBefore = ethers.BigNumber.from(0);
      let bobTknBefore = ethers.BigNumber.from(0);
      let aliceTknAfter = ethers.BigNumber.from(0);
      let bobTknAfter = ethers.BigNumber.from(0);

      let aliceStakeTokenBefore = ethers.BigNumber.from(0);
      let bobStakeTokenBefore = ethers.BigNumber.from(0);
      let aliceStakeTokenAfter = ethers.BigNumber.from(0);
      let bobStakeTokenAfter = ethers.BigNumber.from(0);

      let aliceTokenBarBefore = ethers.BigNumber.from(0);
      let bobTokenBarBefore = ethers.BigNumber.from(0);
      let aliceTokenBarAfter = ethers.BigNumber.from(0);
      let bobTokenBarAfter = ethers.BigNumber.from(0);

      const stages: any = {};

      await optionChef.addPool(100, stakeToken.address, true);

      // 1. Alice deposit 100 stakeToken to OptionChef
      await optionChefAsAlice.deposit(0, ethers.utils.parseUnits("100", 18));

      // 2. Move 1 block
      await timeHelpers.advanceBlock();

      // 3. Alice should has TKN_PER_BLOCK pending TKN
      expect(await optionChef.pendingTkn(0, aliceAddress)).to.be.eq(
        TKN_PER_BLOCK
      );

      // 4. Move 1 block
      await timeHelpers.advanceBlock();

      // 5. Alice should has TKN_PER_BLOCK * 2 pending TKN
      expect(await optionChef.pendingTkn(0, aliceAddress)).to.be.eq(
        TKN_PER_BLOCK.mul(2)
      );

      // 6. Alice harvest TKN
      // - Alice should get Call Option NFT to buy TKN_PER_BLOCK * 3 TKN which will be expired in 7 days
      aliceTokenBarBefore = await tokenBarAsAlice.balanceOf(aliceAddress);
      await optionChefAsAlice.withdraw(0, 0);
      aliceTokenBarAfter = await tokenBarAsAlice.balanceOf(aliceAddress);
      stages["aliceHarvestTkn0"] = [
        await timeHelpers.latestBlockNumber(),
        await timeHelpers.latestTimestamp(),
      ];

      let aliceOptionInfo = await tokenBar.options(0);

      expect(aliceTokenBarAfter.sub(aliceTokenBarBefore)).to.be.eq(1);
      expect(await tokenBar.nextID()).to.be.eq(1);
      expect(await tokenBar.ownerOf(0)).to.be.eq(aliceAddress);
      expect(aliceOptionInfo.amount).to.be.eq(TKN_PER_BLOCK.mul(3));
      expect(aliceOptionInfo.price).to.be.eq(
        TKN_PRICE.mul(DISCOUNT_FACTOR).div(1e4)
      );
      expect(aliceOptionInfo.expiry).to.be.eq(
        stages["aliceHarvestTkn0"][1].add(OPTION_EXIPRY)
      );
      expect(aliceOptionInfo.exercised).to.be.eq(false);

      // Should revert if try to exercies before it is expired
      await expect(tokenBarAsAlice.exercise(0)).to.be.revertedWith("!expired");

      // 7. Move timestamp so that Alice's option is expired
      await timeHelpers.increaseTimestamp(OPTION_EXIPRY);

      // 8. Alice should has TKN_PER_BLOCK pending TKN
      expect(await optionChef.pendingTkn(0, aliceAddress)).to.be.eq(
        TKN_PER_BLOCK
      );

      // Should revert if try to exercise without paying anything
      await expect(tokenBar.exercise(0)).to.be.revertedWith("bad value");

      // Should revert when non-owner without approval try to exercise
      await expect(
        tokenBar.exercise(0, { value: TKN_PRICE.mul(DISCOUNT_FACTOR).div(1e4) })
      ).to.be.revertedWith("not owner");

      // 9. Alice exercise Option#0 to get TKN_PER_BLOCK * 3 TKN
      aliceTknBefore = await token.balanceOf(aliceAddress);
      await tokenBarAsAlice.exercise(0, {
        value: TKN_PRICE.mul(DISCOUNT_FACTOR).div(1e4),
      });
      aliceTknAfter = await token.balanceOf(aliceAddress);
      await expect(tokenBar.ownerOf(0)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );
      expect(aliceTknAfter.sub(aliceTknBefore)).to.be.eq(TKN_PER_BLOCK.mul(3));

      // 10. Alice try to exercise again
      await expect(tokenBarAsAlice.exercise(0)).to.be.revertedWith(
        "already exercised"
      );
    });
  });
});
