use cardano/transaction.{OutputReference, Transaction}
use types.{StakingDatum}

validator staking {
  spend(
    datum: Option<StakingDatum>,
    rdmr: Int,
    my_output_reference: OutputReference,
    self: Transaction,
  ) {
    todo
  }

  withdraw(
    _redmr: Int,
    _my_output_reference: OutputReference,
    _self: Transaction,
  ) {
    todo
  }

  mint(_redmr: Int, _my_output_reference: OutputReference, _self: Transaction) {
    todo
  }

  else(_) {
    fail
  }
}
