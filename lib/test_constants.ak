use cardano/address.{Address, Inline, Script, StakeCredential, VerificationKey}
use types.{AssetClass}

pub const policy_id =
  #"633f004a742cb9d1774c636ea6618f096c8332ba5aa5648ee165c3f0"

pub const staking_script_hash =
  #"633f004a742cb9d1774c636ea6618f096c8332ba5aa5648ee165c3f0"

pub const trader_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const stake_credential_pkh =
  #"6313a1d2c296eb3341e159b6c5c6991de11e81062b95108c9aa024ad"

pub const strike_collateral_policy_id =
  #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"

pub const strike_collateral_asset_name = #"535452494b45"

pub const mint_asset = AssetClass { policy_id, asset_name: trader_pkh }

pub const stake_credential: StakeCredential =
  Inline(VerificationKey(stake_credential_pkh))

pub const strike_collateral_asset =
  AssetClass {
    policy_id: strike_collateral_policy_id,
    asset_name: strike_collateral_asset_name,
  }

pub const staking_address =
  Address {
    payment_credential: Script(staking_script_hash),
    stake_credential: Some(stake_credential),
  }

pub const trader_address =
  Address {
    payment_credential: VerificationKey(trader_pkh),
    stake_credential: Some(stake_credential),
  }
