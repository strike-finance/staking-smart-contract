# Staking

## How It Works

1. Staking rewards are calculated and distributed to all stakers once per day at a predetermined time.
2. Stakers must have their STRIKE stake locked for at least 1 full day before they start earning rewards.
3. All rewards are paid out in ADA.
4. Stakers can add or remove part of the staked STRIKE
5. Stakers can unlock their rewards or withdraw all of their stake anytime

## High Level Overview

This is a multivalidator script with 1 spending script, 1 withdrawal script, and 1 minting script. There are 5 actions that can happen. Stakers will have an UTxO sitting at the multivalidator script. The admin will be depositing assets into the UTxO

The minting script allows the

The spending script allows the user to add stake

1. Stake
2. Add Stake
3. Withdraw Rewards
4. Withdraw Stakes and Rewards
5. Distribute Stake

Distributing of stake will require the admin to create an off-chain script that distributes it fairly.

## Stake

## Add Stake

## Withdraw Rewards

## Withdraw Stakes and Rewards

## Distribute Stake

## Disclaimer

This staking contract only does the following things.

The users stake their tokens. Their tokens and rewarded tokens will be protected and only consumed by themselves. The smart contract ensures the users staked tokens are safe and provide the nessarilly for off-chain code to behave.

The distribution of rewards are not permissionless. It relies on the person to distribute the funds accordingly off-chain. The rewards can potentially be rewarded unproportionally off-chain.

This is not ideal, but we think it is reasonable for a V1. We will iterate and create a more permissionless staking contract once we have all products on-chain.
