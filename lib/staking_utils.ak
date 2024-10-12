use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Script}
use cardano/assets.{lovelace_of, quantity_of}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use types.{StakingDatum}
use utils.{get_lower_bound}

pub fn valid_distribute_rewards(
  validation_logic: fn(Output, Output, Int) -> Bool,
  redeemer: List<(Int, Int)>,
  own_validator: ScriptHash,
  transaction: Transaction,
) -> Bool {
  let Transaction { inputs, outputs, validity_range, .. } = transaction
  let (script_inputs, script_input_count) =
    list.foldr(
      inputs,
      ([], 0),
      fn(i, acc_tuple) {
        let Input { output, .. } = i
        when output.address.payment_credential is {
          Script(script) ->
            if script == own_validator {
              let (acc, count) = acc_tuple
              ([output, ..acc], count + 1)
            } else {
              acc_tuple
            }
          _ -> acc_tuple
        }
      },
    )

  let lower_bound: Int = get_lower_bound(validity_range)

  let indices: List<(Int, Int)> = redeemer
  let (_, _, input_index_count) =
    list.foldl(
      indices,
      (-1, -1, 0),
      fn(curr, acc) {
        let (in0, out0, count) = acc
        let (in1, out1) = curr
        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = script_inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          if validation_logic(in_utxo, out_utxo, lower_bound) {
            (in1, out1, count + 1)
          } else {
            fail @"Validation failed"
          }
        } else {
          fail @"Input and output indices must be in ascending orders"
        }
      },
    )
  (script_input_count == input_index_count)?
}

pub fn validation_logic(input: Output, output: Output, lower_bound: Int) -> Bool {
  expect InlineDatum(input_datum) = input.datum
  expect input_datum_typed: StakingDatum = input_datum

  expect InlineDatum(output_datum) = output.datum
  expect output_datum_typed: StakingDatum = output_datum

  expect Some(output_stake_credential) = output.address.stake_credential

  expect Some(input_stake_credential) = input.address.stake_credential

  let stake_credential_is_valid =
    output_stake_credential == input_stake_credential

  let datum_valid: Bool =
    output_datum_typed.owner_address_hash == input_datum_typed.owner_address_hash && output_datum_typed.staking_asset == input_datum_typed.staking_asset

  let lovelace_amount_increased =
    lovelace_of(output.value) >= lovelace_of(input.value)

  let staking_mint_asset_returned =
    quantity_of(
      output.value,
      input_datum_typed.mint_asset.policy_id,
      input_datum_typed.mint_asset.asset_name,
    ) == 1

  let updated_lower_bount = output_datum_typed.last_rewarded_time >= lower_bound

  stake_credential_is_valid && datum_valid && lovelace_amount_increased && staking_mint_asset_returned && updated_lower_bount
}
