module contract::voting;

use sui::table::{Self, Table};

use std::string::String;
use std::type_name::{Self, TypeName};

// errors
const ETypeNotWhitelisted: u64 = 0;
const ETypeNotEnabled: u64 = 1;
const EVoteAlreadyCast: u64 = 2;
const EInvalidSubmission: u64 = 3;
const EVoteNotCast: u64 = 4;


// This is a registry with all the tokens that are allowed to vote and the votes themselves
// Assumes that there is only one hackathon at one time that community can vote for.
// Allows an address to vote multiple times if they own many allowed types, but only once per type
public struct EventVotes has key {
    id: UID,
    name: String,
    whitelist: Table<TypeName, bool>,
    votes: Table<String, u32>,
    voter_used_id: Table<ID, bool>
}

public struct Ballot has key {
    id: UID,
    votes: vector<String>
}


public struct OrganizerCap has key, store {
    id: UID,
}


fun init(ctx: &mut TxContext) {
    let cap = OrganizerCap {
        id: object::new(ctx)
    };
    transfer::public_transfer(cap, ctx.sender());
}

// Gated functions

// new_event returns the EventVotes object but this should be shared in the same PTB, the idea is that allowed types can be added before being shared
public fun new_event(_: &OrganizerCap, name: String, mut submissions: vector<String>, ctx: &mut TxContext): EventVotes {
    let mut votes = table::new<String, u32>(ctx);
    while(!submissions.is_empty()) {
        let sumbmission = submissions.pop_back<String>();
        votes.add<String, u32>(sumbmission, 0u32);
    };
    let event = EventVotes {
        id: object::new(ctx),
        name,
        whitelist: table::new<TypeName, bool>(ctx),
        votes,
        voter_used_id: table::new<ID, bool>(ctx)
    };

    event
}

public fun add_eligible_type<T>(self: &mut EventVotes, _: &OrganizerCap) {
    let tn = type_name::get<T>();
    self.whitelist.add<TypeName, bool>(tn, true);
}

public fun disable_type<T>(self: &mut EventVotes, _: &OrganizerCap) {
    let tn = type_name::get<T>();
    assert!(self.whitelist.contains(tn), ETypeNotWhitelisted);
    *self.whitelist.borrow_mut<TypeName, bool>(tn) = false;
}

public fun enable_type<T>(self: &mut EventVotes, _: &OrganizerCap) {
    let tn = type_name::get<T>();
    assert!(self.whitelist.contains(tn), ETypeNotWhitelisted);
    *self.whitelist.borrow_mut<TypeName, bool>(tn) = true;
}

public fun remove_type<T>(self: &mut EventVotes, _: &OrganizerCap) {
    let tn = type_name::get<T>();
    assert!(self.whitelist.contains(tn), ETypeNotWhitelisted);
    self.whitelist.remove<TypeName, bool>(tn);
}

public fun delete_event(self: EventVotes, _: &OrganizerCap) {
    let EventVotes {id, name: _,  whitelist, votes, voter_used_id} = self;
    whitelist.drop();
    votes.drop();
    voter_used_id.drop();
    id.delete();
}

// to be called in the same PTB as new_event
public fun share_event(self: EventVotes) {
    transfer::share_object(self);
}

// The only user function

fun check_eligibility<T: key>(self: &EventVotes, nft: &T, submissions: vector<String>) {
    //check if submissions exist
    submissions.do!(|s| {
        assert!(self.votes.contains(s), EInvalidSubmission);
    });
    let tn = type_name::get<T>();
    // check if valid type is presented
    assert!(self.whitelist.contains(tn), ETypeNotWhitelisted);
    // check that type is enabled
    assert!(*self.whitelist.borrow<TypeName, bool>(tn), ETypeNotEnabled);
}

public fun vote<T: key>(self: &mut EventVotes, nft: &T, submissions: vector<String>, ctx: &mut TxContext) {
    check_eligibility(self, nft, submissions);
    // check if user has not voted already with this ID
    assert!(!self.voter_used_id.contains(object::id(nft)), EVoteAlreadyCast);

    // add type to used ones
    self.voter_used_id.add(object::id(nft), true);

    submissions.do!(|s| {
        // increase vote count
        *self.votes.borrow_mut<String, u32>(s) = *self.votes.borrow_mut<String, u32>(s) + 1u32;
    });
    let b = Ballot {
        id: object::new(ctx),
        votes: submissions
    };
    transfer::transfer(b, ctx.sender());
}

public fun revote<T: key>(self: &mut EventVotes, nft: &T, ballot: &mut Ballot, resubmissions: vector<String>) {
    check_eligibility(self, nft, resubmissions);
    // Check if user has voted already with this ID
    assert!(self.voter_used_id.contains(object::id(nft)), EVoteNotCast);
    
    // decrease previous votes
    ballot.votes.do!(|s| {
        *self.votes.borrow_mut<String, u32>(s) = *self.votes.borrow_mut<String, u32>(s) - 1u32;
    });

    resubmissions.do!(|s| {
        // increase vote count
        *self.votes.borrow_mut<String, u32>(s) = *self.votes.borrow_mut<String, u32>(s) + 1u32;
    });
    ballot.votes = resubmissions;
}


// getters
public fun votes(self: &mut EventVotes, submission: String): u32 {
    *self.votes.borrow(submission)
}

// Test helpers
#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(ctx);
}

