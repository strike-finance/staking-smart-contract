use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/address.{StakeCredential}
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
  staking_asset: AssetClass,
  mint_asset: AssetClass,
  staked_at: POSIXTime,
}

pub type StakingRedeemer {
  AddStakeOrConsumeStakingRewards
  WithdrawStake
  DistributeStakingRewards
}

pub type MintRedeemer {
  Mint
  Burn(AssetName)
}

pub type StakingParams {
  admin_pkh: AddressHash,
  staking_policy_id: PolicyId,
  staking_asset_name: ByteArray,
  stake_credential: StakeCredential,
}
