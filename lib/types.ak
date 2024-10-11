use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type AddressHash =
  Hash<Blake2b_224, VerificationKey>

pub type POSIXTime =
  Int

pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type StakingDatum {
  owner_address_hash: AddressHash,
  strike_asset: AssetClass,
  staking_mint_asset: AssetClass,
  last_rewarded_time: POSIXTime,
}

pub type StakingRedeemer {
  ConsumeStakingRewards
  WithdrawStake
  DistributeStakingRewards
}

pub type MintRedeemer {
  Mint
  Burn(AssetName)
}
