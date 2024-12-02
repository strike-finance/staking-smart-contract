use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Credential, Script}
use cardano/assets.{PolicyId, lovelace_of, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_input,
  find_script_outputs,
}
use constants.{min_lovelace_in_utxo}
use staking_utils.{valid_distribute_rewards, validation_logic}
use test_constants.{
  admin_pkh, asset_name, mint_asset, policy_id, stake_credential,
  stake_script_credential, staking_address, strike_collateral_asset,
  strike_collateral_asset_name, strike_collateral_policy_id, trader_address,
  trader_pkh,
}
use types.{
  AddStakeOrConsumeStakingRewards, AssetClass, Burn, DistributeStakingRewards,
  Mint, MintRedeemer, StakingDatum, StakingParams, StakingRedeemer,
  WithdrawStake,
}
use utils.{
  compare_stake, get_address_outputs, get_script_hash, get_upper_bound,
  get_validators_inputs,
}

validator staking(params: StakingParams) {
  spend(
    datum: Option<StakingDatum>,
    rdmr: StakingRedeemer,
    my_output_reference: OutputReference,
    transaction: Transaction,
  ) {
    when rdmr is {
      AddStakeOrConsumeStakingRewards -> {
        expect Some(datum) = datum
        let signed_by_owner =
          list.has(transaction.extra_signatories, datum.owner_address_hash)

        expect Some(input_from_validator) =
          transaction.inputs
            |> transaction.find_input(my_output_reference)

        let only_one_validator_input: Bool =
          list.length(get_validators_inputs(transaction)) == 1

        let outputs_to_validator: List<Output> =
          get_address_outputs(transaction, input_from_validator.output.address)

        expect Some(output_to_validator) = list.head(outputs_to_validator)

        expect Some(output_stake_credential) =
          output_to_validator.address.stake_credential

        let stake_credential_is_valid =
          output_stake_credential == params.stake_credential

        expect InlineDatum(output_datum) = output_to_validator.datum

        expect output_datum_typed: StakingDatum = output_datum

        let datum_valid: Bool =
          output_datum_typed.owner_address_hash == datum.owner_address_hash && output_datum_typed.staking_asset == datum.staking_asset && output_datum_typed.staked_at == datum.staked_at && output_datum_typed.mint_asset == datum.mint_asset

        let return_min_lovelace_valid =
          lovelace_of(output_to_validator.value) >= min_lovelace_in_utxo

        let quantity_of_staking_asset_in_input =
          quantity_of(
            input_from_validator.output.value,
            params.staking_policy_id,
            params.staking_asset_name,
          )

        let expected_assets_locked =
          assets.from_lovelace(min_lovelace_in_utxo)
            |> assets.add(
                params.staking_policy_id,
                params.staking_asset_name,
                quantity_of_staking_asset_in_input,
              )
            |> assets.add(policy_id, params.asset_name, 1)
            |> assets.add(policy_id, output_datum_typed.owner_address_hash, 1)

        let assets_match =
          match(output_to_validator.value, expected_assets_locked, >=)

        signed_by_owner && stake_credential_is_valid && only_one_validator_input && datum_valid && return_min_lovelace_valid && assets_match
      }
      WithdrawStake -> {
        expect Some(datum) = datum
        let signed_by_owner =
          list.has(transaction.extra_signatories, datum.owner_address_hash)

        let expected_assets_burnt =
          assets.from_asset(
            datum.mint_asset.policy_id,
            datum.mint_asset.asset_name,
            -1,
          )
            |> assets.add(datum.mint_asset.policy_id, datum.owner_address_hash, -1)

        let valid_mint = expected_assets_burnt == transaction.mint

        signed_by_owner && valid_mint
      }
      DistributeStakingRewards -> {
        expect Some(input) = find_input(transaction.inputs, my_output_reference)

        let withdrawals = transaction.withdrawals

        let own_withdrawal = input.output.address.payment_credential

        pairs.has_key(withdrawals, own_withdrawal)
      }
    }
  }

  withdraw(
    redeemer: List<(Int, Int)>,
    credential: Credential,
    transaction: Transaction,
  ) {
    expect Script(own_validator) = credential

    let admin_signed = list.has(transaction.extra_signatories, params.admin_pkh)

    let valid_distribute =
      valid_distribute_rewards(
        validation_logic,
        redeemer,
        own_validator,
        transaction,
      )

    valid_distribute && admin_signed
  }

  mint(redeemer: MintRedeemer, policy_id: PolicyId, transaction: Transaction) {
    when redeemer is {
      Mint -> {
        let outputs_to_forward_contract: List<Output> =
          find_script_outputs(transaction.outputs, policy_id)

        expect Some(output_to_forward_contract) =
          list.head(outputs_to_forward_contract)

        expect InlineDatum(output_datum) = output_to_forward_contract.datum

        expect output_datum_typed: StakingDatum = output_datum

        let expected_assets_minted =
          assets.from_asset(policy_id, params.asset_name, 1)
            |> assets.add(policy_id, output_datum_typed.owner_address_hash, 1)

        let valid_mint = expected_assets_minted == transaction.mint

        let output_script_hash =
          get_script_hash(output_to_forward_contract.address)

        let output_is_to_forward_validator = output_script_hash == policy_id

        expect Some(output_to_forward_stake_credential) =
          output_to_forward_contract.address.stake_credential

        let stake_credential_is_valid =
          compare_stake(
            output_to_forward_stake_credential,
            params.stake_credential,
          )

        let signed_by_owner =
          list.has(
            transaction.extra_signatories,
            output_datum_typed.owner_address_hash,
          )

        let asset_is_valid =
          output_datum_typed.mint_asset.policy_id == policy_id && output_datum_typed.mint_asset.asset_name == params.asset_name

        let staking_asset_is_valid =
          output_datum_typed.staking_asset.policy_id == params.staking_policy_id && output_datum_typed.staking_asset.asset_name == params.staking_asset_name
        // the asset required for staking
        // minted assets to validate the stake is valid
        // minted asset with owner pubkeyhash for better offchain indexing
        let expected_assets_locked =
          assets.from_lovelace(min_lovelace_in_utxo)
            |> assets.add(params.staking_policy_id, params.staking_asset_name, 1)
            |> assets.add(policy_id, params.asset_name, 1)
            |> assets.add(policy_id, output_datum_typed.owner_address_hash, 1)

        let assets_match =
          match(output_to_forward_contract.value, expected_assets_locked, >=)

        let min_lovelace_in_output =
          lovelace_of(output_to_forward_contract.value) == min_lovelace_in_utxo

        let last_rewarded_time_is_valid =
          get_upper_bound(transaction.validity_range) >= output_datum_typed.staked_at

        output_is_to_forward_validator && signed_by_owner && stake_credential_is_valid && valid_mint && min_lovelace_in_output && last_rewarded_time_is_valid && staking_asset_is_valid && asset_is_valid && assets_match
      }

      Burn(asset_name, owner_address_hash) -> {
        let expected_burnt =
          assets.from_asset(policy_id, asset_name, -1)
            |> assets.add(policy_id, owner_address_hash, -1)

        let valid_mint = expected_burnt == transaction.mint

        valid_mint
      }
    }
  }

  else(_) {
    fail
  }
}

test mint() {
  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_asset,
      staking_asset: strike_collateral_asset,
      staked_at: 1727453227631,
    }

  let staking_sent =
    assets.from_asset(
      strike_collateral_asset.policy_id,
      strike_collateral_asset.asset_name,
      1,
    )

  let mint = assets.from_asset(policy_id, asset_name, 1)

  let staker_identifier_mint = assets.from_asset(policy_id, trader_pkh, 1)

  let pos_out =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint)
        |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let minted = assets.merge(mint, staker_identifier_mint)

  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [],
      outputs: [pos_out],
      fee: 0,
      mint: minted,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: strike_collateral_policy_id,
      staking_asset_name: strike_collateral_asset_name,
      stake_credential,
    }
  let redeemer = Mint
  staking.mint(params, redeemer, policy_id, tx)
}

test add_stake() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_asset,
      staking_asset: strike_collateral_asset,
      staked_at: 1727453227631,
    }

  let mint = assets.from_asset(policy_id, asset_name, 1)
  let staker_identifier_mint_sent = assets.from_asset(policy_id, trader_pkh, 1)

  let staking_sent =
    assets.from_asset(
      strike_collateral_asset.policy_id,
      strike_collateral_asset.asset_name,
      1,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint_sent)
        |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: strike_collateral_policy_id,
      staking_asset_name: strike_collateral_asset_name,
      stake_credential,
    }
  let redeemer = AddStakeOrConsumeStakingRewards
  staking.spend(params, Some(stake_datum), redeemer, own_ref, tx)
}

test consume_rewards() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_asset,
      staking_asset: strike_collateral_asset,
      staked_at: 1727453227631,
    }

  let mint = assets.from_asset(policy_id, asset_name, 1)
  let staker_identifier_mint_sent = assets.from_asset(policy_id, trader_pkh, 1)
  let staking_sent =
    assets.from_asset(
      strike_collateral_asset.policy_id,
      strike_collateral_asset.asset_name,
      10,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(6_000_000)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint_sent)
        |> assets.merge(assets.from_lovelace(min_lovelace_in_utxo)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: strike_collateral_policy_id,
      staking_asset_name: strike_collateral_asset_name,
      stake_credential,
    }
  let redeemer = AddStakeOrConsumeStakingRewards
  staking.spend(params, Some(stake_datum), redeemer, own_ref, tx)
}

test withdraw_stake() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_asset,
      staking_asset: strike_collateral_asset,
      staked_at: 1727453227631,
    }

  let mint = assets.from_asset(policy_id, asset_name, 1)
  let staker_identifier_mint_sent = assets.from_asset(policy_id, trader_pkh, 1)

  let burnt_mint = assets.from_asset(policy_id, asset_name, -1)
  let staker_identifier_mint_burnt =
    assets.from_asset(policy_id, trader_pkh, -1)

  let staking_sent =
    assets.from_asset(
      strike_collateral_asset.policy_id,
      strike_collateral_asset.asset_name,
      10,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(6_000_000)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: trader_address,
      value: staking_sent
        |> assets.merge(assets.from_lovelace(6_000_000)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: burnt_mint |> assets.merge(staker_identifier_mint_burnt),
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    StakingParams {
      admin_pkh: trader_pkh,
      asset_name,
      staking_policy_id: strike_collateral_policy_id,
      staking_asset_name: strike_collateral_asset_name,
      stake_credential,
    }
  let redeemer = WithdrawStake
  staking.spend(params, Some(stake_datum), redeemer, own_ref, tx)
}

test prop_withdraw_validator() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let stake_datum =
    StakingDatum {
      owner_address_hash: trader_pkh,
      mint_asset,
      staking_asset: strike_collateral_asset,
      staked_at: 1727453227631,
    }

  let mint = assets.from_asset(policy_id, asset_name, 1)
  let staker_identifier_mint_sent = assets.from_asset(policy_id, trader_pkh, 1)

  let staking_sent =
    assets.from_asset(
      strike_collateral_asset.policy_id,
      strike_collateral_asset.asset_name,
      10,
    )

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: staking_address,
        value: mint
          |> assets.merge(staking_sent)
          |> assets.merge(staker_identifier_mint_sent)
          |> assets.merge(assets.from_lovelace(6_000_000)),
        datum: InlineDatum(stake_datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: staking_address,
      value: mint
        |> assets.merge(staking_sent)
        |> assets.merge(staker_identifier_mint_sent)
        |> assets.merge(assets.from_lovelace(6_000_000)),
      datum: InlineDatum(stake_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [admin_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let redeemer = [(0, 0)]
  let params =
    StakingParams {
      admin_pkh,
      asset_name,
      staking_policy_id: strike_collateral_policy_id,
      staking_asset_name: strike_collateral_asset_name,
      stake_credential,
    }
  staking.withdraw(params, redeemer, stake_script_credential, tx)
}
