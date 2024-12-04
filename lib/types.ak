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
  staked_at: POSIXTime,
  mint_policy_id: PolicyId,
}

pub type StakingRedeemer {
  AddStakeOrConsumeStakingRewards
  WithdrawStake
  DistributeStakingRewards
}

pub type MintRedeemer {
  Mint(Int)
  Burn(AddressHash)
}

pub type StakingParams {
  admin_pkh: AddressHash,
  asset_name: AssetName,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
  stake_credential: ByteArray,
}
