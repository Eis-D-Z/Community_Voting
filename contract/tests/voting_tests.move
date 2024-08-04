#[test_only]
module contract::voting_tests {
    use sui::test_scenario::{Self as ts, Scenario};

    use std::string::{Self, String};

    use contract::voting::{
        Self,
        OrganizerCap,
        EventVotes,
        ETypeNotEnabled,
        ETypeNotWhitelisted,
        EVoteAlreadyCast,
        EInvalidSubmission
    };

    const ORGANIZER: address = @0xAAA;
    const VOTER1: address = @0xBBB;
    const VOTER2: address = @0xCCC;

    public struct Type1 has key, store {
        id: UID,
    }

    public struct Type2 has key, store {
        id: UID
    }

    #[test_only]
    public fun mint_type1(ctx: &mut TxContext): Type1 {
        Type1 {
            id: object::new(ctx)
        }
    }

    #[test_only]
    public fun mint_type2(ctx: &mut TxContext): Type2 {
        Type2 {
            id: object::new(ctx)
        }
    }

    #[test]
    public fun initialize(): Scenario {
        let mut scenario = ts::begin(ORGANIZER);

        let submissions: vector<String> = vector[
            string::utf8(b"Sub1"),
            string::utf8(b"Sub2"),
            string::utf8(b"Sub3"),
        ];

        voting::init_for_test(scenario.ctx());

        ts::next_tx(&mut scenario, ORGANIZER);
        {
            let cap = ts::take_from_sender<OrganizerCap>(&scenario);
            let mut event = voting::new_event(&cap, string::utf8(b"Hackahon"), submissions, scenario.ctx());
            event.add_eligble_type<Type1>(&cap);
            event.add_eligble_type<Type2>(&cap);

            voting::share_event(event);
            ts::return_to_sender<OrganizerCap>(&scenario, cap);

        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let nft1 = mint_type1(scenario.ctx());
            let nft2 = mint_type1(scenario.ctx());
            let nft3 = mint_type2(scenario.ctx());

            transfer::public_transfer(nft1, VOTER1);
            transfer::public_transfer(nft3, VOTER1);
            transfer::public_transfer(nft2, VOTER2);

        };

        scenario
    }

    #[test]
    public fun test_disable_type1 (): Scenario {
        let mut scenario = initialize();

        ts::next_tx(&mut scenario, ORGANIZER);
        {
            let cap = ts::take_from_sender<OrganizerCap>(&scenario);
            let mut event = scenario.take_shared<EventVotes>();

            event.disable_type<Type1>(&cap);

            ts::return_to_sender(&scenario, cap);
            ts::return_shared(event);
        };

        scenario
    }
    
    #[test]
    public fun test_enable_type1 (): Scenario {
        let mut scenario = test_disable_type1();
        ts::next_tx(&mut scenario, ORGANIZER);
        {
            let cap = ts::take_from_sender<OrganizerCap>(&scenario);
            let mut event = scenario.take_shared<EventVotes>();

            event.enable_type<Type1>(&cap);

            ts::return_to_sender(&scenario, cap);
            ts::return_shared(event);
        };

        scenario
    }

    #[test]
    public fun test_remove_type1 (): Scenario {
        let mut scenario = test_enable_type1();
        scenario.next_tx(ORGANIZER);
        {
            let cap = scenario.take_from_sender<OrganizerCap>();
            let mut event = scenario.take_shared<EventVotes>();

            event.remove_type<Type1>(&cap);

            ts::return_to_sender(&scenario, cap);
            ts::return_shared(event);
        };

        scenario
    }

    #[test]
    public fun test_delete_event () {
        let mut scenario = initialize();

        scenario.next_tx(ORGANIZER);
        {
            let cap = ts::take_from_sender<OrganizerCap>(&scenario);
            let mut event = scenario.take_shared<EventVotes>();

            event.delete_event(&cap);

            scenario.return_to_sender(cap);

        };

        ts::end(scenario);
    }

    #[test]
    public fun test_vote() {
        let mut scenario = initialize();

        ts::next_tx(&mut scenario, VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub1"), scenario.ctx());

            scenario.return_to_sender(nft_type1);
            ts::return_shared(event);

        };

        ts::next_tx(&mut scenario, VOTER2);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub3"), scenario.ctx());

            scenario.return_to_sender(nft_type1);
            ts::return_shared(event);

        };

        scenario.end();
    }

    #[test]
    public fun test_vote_twice_success() {
        let mut scenario = initialize();

        ts::next_tx(&mut scenario, VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub1"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event);

        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let nft_type2 = scenario.take_from_sender<Type2>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type2>(&nft_type2, string::utf8(b"Sub3"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type2);
            ts::return_shared(event);

        };

        ts::next_tx(&mut scenario, VOTER2);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub3"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event);

        };

        // check result
        scenario.next_tx(VOTER1);
        {
            let mut event = scenario.take_shared<EventVotes>();
            assert!(event.votes(string::utf8(b"Sub1")) == 1u32, 0);
            assert!(event.votes(string::utf8(b"Sub2")) == 0u32, 0);
            assert!(event.votes(string::utf8(b"Sub3")) == 2u32, 0);

            ts::return_shared(event);
        };

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = ETypeNotEnabled)]
    public fun test_vote_on_disabled_type() {
        let mut scenario = test_disable_type1();
        scenario.next_tx(VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub1"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event); 
        };

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = ETypeNotWhitelisted)]
    public fun test_vote_on_inexistent_type() {
        let mut scenario = test_remove_type1();
        scenario.next_tx(VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub1"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event); 
        };

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EVoteAlreadyCast)]
    public fun test_vote_twice_with_same_type() {
        let mut scenario = initialize();

        scenario.next_tx(VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub1"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event); 
        };

        scenario.next_tx(VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Sub1"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event); 
        };

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidSubmission)]
    public fun test_vote_on_inexistest_option() {
        let mut scenario = initialize();
        scenario.next_tx(VOTER1);
        {
            let nft_type1 = scenario.take_from_sender<Type1>();
            let mut event = scenario.take_shared<EventVotes>();

            event.vote<Type1>(&nft_type1, string::utf8(b"Eis D. Zaster"), scenario.ctx());

            ts::return_to_sender(&scenario, nft_type1);
            ts::return_shared(event); 
        };

        scenario.end();
    }

}
