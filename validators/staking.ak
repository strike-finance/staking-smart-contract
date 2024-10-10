use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{StakeCredential}
use cardano/assets.{PolicyId, lovelace_of, quantity_of}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, find_input,
}
use constants.{min_lovelace_in_utxo}
use types.{
  Burn, ConsumeStakingRewards, DistributeStakingRewards, Mint, MintRedeemer,
  StakingDatum, StakingRedeemer, WithdrawStake,
}
use utils.{get_address_outputs, get_validators_inputs, validate_token_mint}

validator staking(
  strike_stake_credential: StakeCredential,
  asset_name: ByteArray,
) {
  spend(
    datum: Option<StakingDatum>,
    rdmr: StakingRedeemer,
    my_output_reference: OutputReference,
    transaction: Transaction,
  ) {
    when rdmr is {
      ConsumeStakingRewards -> {
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
          output_stake_credential == strike_stake_credential

        expect InlineDatum(output_datum) = output_to_validator.datum

        expect output_datum_typed: StakingDatum = output_datum

        let datum_valid: Bool =
          output_datum_typed.owner_address_hash == datum.owner_address_hash && output_datum_typed.strike_asset == datum.strike_asset && output_datum_typed.last_rewarded_time == datum.last_rewarded_time

        let return_min_lovelace_valid =
          lovelace_of(output_to_validator.value) >= min_lovelace_in_utxo

        let staking_mint_asset_returned =
          quantity_of(
            output_to_validator.value,
            datum.staking_mint_asset.policy_id,
            datum.staking_mint_asset.asset_name,
          ) == 1

        signed_by_owner && stake_credential_is_valid && only_one_validator_input && datum_valid && return_min_lovelace_valid && staking_mint_asset_returned
      }
      WithdrawStake -> {
        expect Some(datum) = datum
        let signed_by_owner =
          list.has(transaction.extra_signatories, datum.owner_address_hash)

        let expected_burnt =
          (
            datum.staking_mint_asset.policy_id,
            datum.staking_mint_asset.asset_name,
            -1,
          )

        let valid_mint = validate_token_mint(transaction.mint, expected_burnt)

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
    _redmr: Int,
    _my_output_reference: OutputReference,
    _self: Transaction,
  ) {
    todo
  }

  mint(redeemer: MintRedeemer, policy_id: PolicyId, transaction: Transaction) {
    when redeemer is {
      Mint -> todo
      Burn -> {
        let expected_burnt = (policy_id, asset_name, -1)

        let valid_mint = validate_token_mint(transaction.mint, expected_burnt)

        valid_mint
      }
    }
  }

  else(_) {
    fail
  }
}
