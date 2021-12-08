# OptionChef 👨‍🍳

OptionChef is a variant of MasterChef where we applied "Call Option" to liquidity mining program.

## Why?

It is crystal clear that protocols with on-going incentives (a.k.a liquidity mining) face with constants selling pressure and struggle 
to discover the floor price of their tokens. This also harms traders who just want to buy tokens from the open market due to continuos selling 
pressure from token emission. We do believe this is the problem of giving away something for nothing. For example, if you provide BUSD + USDT to 
farm $CAKE, you probably sell $CAKE right away once you received it as you have ZERO cost of acquiring $CAKE. Just provide liquidity, get rewarded, simple.

## Apply "Call Option" to liquidity mining program

So instead of giving out reward tokens right away, a protocol could issue the right to buy reward tokens at discount (a.k.a Call Option) to liquidity miners. 
Assuming $CAKE is trading at $15. Let's say liquidity miners mined 1,000 $CAKE, instead of giving 1,000 $CAKE for free, now they would receive the right to 
buy $CAKE@$7.5. They will still be incentivised to be liquidity providers as they still make profit from exercise the call option. The protocol will also earn 
revenue from liquidity miners exercised their Call Option. This revenue then can be used as liquidity provision, buyback&burn treasury, market making, etc.

We do belive that switching from traditional MasterChef to OptionChef would decrease selling pressure from liquidity mining program, better price discovery, and 
additional source of income for the Gov token holders, while still create a fair distribution of tokens.

## Setup

To get started, clone the repo and install the developer dependencies:


```bash
git clone https://github.com/100x/optionchef.git
cd optionchef
yarn install

```


## Compile & run the tests


```bash
yarn compile
yarn test
```

## Audits and Security

OptionChef contracts have NOT been audited, use at your own risk.

## License

[MIT License](https://opensource.org/licenses/MIT)
