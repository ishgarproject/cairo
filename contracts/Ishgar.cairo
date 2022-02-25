%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add
)
from starkware.starknet.common.syscalls import get_caller_address
from contracts.lib.Ownable_base import (
    Ownable_initializer,
    Ownable_get_owner,
    Ownable_transfer_ownership
)

###############
### Structs ###
###############

struct NFTDeposit:
    member depositor: felt
    member erc721_address: felt
    member token_id: felt
    member ask_price_in_wei: Uint256
end

struct Bid:
    member creator: felt
    member deposit_id: Uint256
    member price: Uint256  # in wei
end

###############
### Storage ###
###############

@storage_var
func _nft_deposits(id: Uint256) -> (nft_deposit: NFTDeposit):
end

@storage_var
func _ether_balances(account: felt) -> (ether_balance: Uint256):
end

@storage_var
func _bids(id: Uint256) -> (bid: Bid):
end

@storage_var
func _asks(id: Uint256) -> (bid: Bid):
end

@storage_var
func _total_nft_deposits() -> (total_nft_deposits: Uint256):
end

@storage_var
func _total_bids() -> (total_bids: Uint256):
end

@storage_var
func _total_asks() -> (total_asks: Uint256):
end

##############
### Events ###
##############

@event
func nft_deposit_(account: felt, erc721_address: felt, token_id: felt):
end

@event
func ether_deposit_(account: felt, amount_in_wei: Uint256):
end

@event
func bid_(account: felt, deposit_id: Uint256, price_in_wei: Uint256):
end

@event
func ask_(account: felt, deposit_id: Uint256, price_in_wei: Uint256):
end

# TODO: add L1 contract check
# TODO: add orders
# TODO: add nft withdraw
# TODO: add ether withdraw

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    let (caller_address) = get_caller_address()
    Ownable_initializer(caller_address)
    return ()
end

###################
### L1 Handlers ###
###################

# TODO: verify edge cases for 'account' parameter
@l1_handler
func deposit_nft{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_address: felt, account: felt, erc721_address: felt, token_id: felt):
    assert_not_zero(account)
    assert_not_zero(erc721_address)

    let (total_nft_deposits: Uint256) = _total_nft_deposits.read()

    let nft_deposit = NFTDeposit(account, erc721_address, token_id, Uint256(1, 0))
    _nft_deposits.write(total_nft_deposits, nft_deposit)

    let new_total_nft_deposits: Uint256 = uint256_add(total_nft_deposits, Uint256(1, 0))
    _total_nft_deposits.write(new_total_nft_deposits)

    nft_deposit_.emit(account, erc721_address, token_id)

    return ()
end

@l1_handler
func deposit_ether{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_address: felt, account: felt, amount_in_wei: Uint256):
    assert_not_zero(account)

    let (ether_balance: Uint256) = _ether_balances.read(account)
    let new_ether_balance: Uint256 = uint256_add(ether_balance, amount_in_wei)
    _ether_balances.write(account, new_ether_balance)

    ether_deposit_.emit(account, amount_in_wei)

    return ()
end

#################
### Externals ###
#################

# TODO: check if deposit still exists
@external
func create_bid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256, price_in_wei: Uint256):
    let (caller_address) = get_caller_address()

    let bid = Bid(caller_address, deposit_id, price_in_wei)

    let (total_bids: Uint256) = _total_bids.read()
    _bids.write(total_bids, bid)

    let new_total_bids: Uint256 = uint256_add(total_bids, Uint256(1, 0))
    _total_bids.write(new_total_bids)

    bid_.emit(caller_address, deposit_id, price_in_wei)
    return ()
end

@external
func create_ask{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256, price_in_wei: Uint256):
    let (caller_address) = get_caller_address()

    let (nft_deposit) = _nft_deposits.read(deposit_id)
    assert nft_deposit.depositor = caller_address

    let deposit_updated = NFTDeposit(
        nft_deposit.depositor,
        nft_deposit.erc721_address,
        nft_deposit.token_id,
        price_in_wei
    )
    _nft_deposits.write(deposit_id, deposit_updated)

    ask_.emit(nft_deposit.depositor, deposit_id, price_in_wei)
    return ()
end

###############
### Getters ###
###############

@view
func get_nft_deposit{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256) -> (nft_deposit: NFTDeposit):
    let (nft_deposit) = _nft_deposits.read(deposit_id)
    return (nft_deposit)
end

@view
func get_bid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(bid_id: Uint256) -> (bid: Bid):
    let (bid) = _bids.read(bid_id)
    return (bid)
end

@view
func get_ask{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256) -> (price_in_wei: Uint256):
    let (nft_deposit) = _nft_deposits.read(deposit_id)
    return (nft_deposit.ask_price_in_wei)
end

@view
func get_total_bids{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (total_bids: Uint256):
    let (total_bids) = _total_bids.read()
    return (total_bids)
end

@view
func get_total_asks{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (total_asks: Uint256):
    let (total_asks) = _total_asks.read()
    return (total_asks)
end

@view
func get_total_nft_deposits{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (total_nft_deposits: Uint256):
    let (total_nft_deposits) = _total_nft_deposits.read()
    return (total_nft_deposits)
end

@view
func get_ether_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (ether_balance: Uint256):
    let (ether_balance) = _ether_balances.read(account)
    return (ether_balance)
end
