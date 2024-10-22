use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash}
use aiken/interval.{Finite}
use aiken/primitive/bytearray
use cardano/address.{
  Address, Credential, Inline, Script, StakeCredential, VerificationKey,
}
use cardano/assets.{PolicyId, Value, flatten, tokens}
use cardano/transaction.{Input, Output, Transaction, ValidityRange}

pub fn get_address_outputs(
  transaction: Transaction,
  address: Address,
) -> List<Output> {
  list.filter(transaction.outputs, fn(output) { output.address == address })
}

pub fn get_validators_inputs(transaction: Transaction) -> List<Input> {
  list.filter(
    transaction.inputs,
    fn(input) { is_script_credential(input.output.address.payment_credential) },
  )
}

pub fn is_script_credential(credential: Credential) -> Bool {
  when credential is {
    Script(_validator_hash) -> True
    _ -> False
  }
}

pub fn validate_token_mint(
  mints: Value,
  expected_minting: (ByteArray, ByteArray, Int),
) -> Bool {
  when list.find(flatten(mints), fn(mint) { mint == expected_minting }) is {
    Some(_) -> only_one_token_in_policy_minted(mints, expected_minting)
    None -> False
  }
}

// Make sure only two token is minted from the asset tuple
fn only_one_token_in_policy_minted(mints, expected_minting) {
  let (policy_id, _, _) = expected_minting
  let policy_id: PolicyId = policy_id
  // Check for the policy mints
  list.length(dict.keys(tokens(mints, policy_id))) == 2
  // Total count of minted unique tokens with policy is two
}

pub fn get_script_hash(address: Address) -> ScriptHash {
  when address.payment_credential is {
    Script(validator_hash) -> validator_hash
    _ -> fail
  }
}

pub fn get_lower_bound(range: ValidityRange) -> Int {
  expect Finite(lower_bound) = range.lower_bound.bound_type
  lower_bound
}

pub fn compare_stake(left: StakeCredential, right: StakeCredential) -> Bool {
  trace @"left": left
  trace @"right": right
  let left =
    when left is {
      Inline(Script(x)) -> x
      Inline(VerificationKey(x)) -> x
      _ -> fail
    }
  let right =
    when right is {
      Inline(Script(x)) -> x
      Inline(VerificationKey(x)) -> x
      _ -> fail
    }

  let result = bytearray.compare(left, right)

  when result is {
    Less -> False
    Equal -> True
    Greater -> False
  }
}
