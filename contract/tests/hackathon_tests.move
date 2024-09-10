#[test_only]
module contract::hackathon_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::random::{Self,Random};

    use contract::walrus_hackathon::{
        Self,
        OrganizerCap,
        TeamPolarBear,
        TeamOrca,
        ShortListed,
        add_projects,
        select_teams,
    };

    const ORGANIZER: address = @0xAAA;
    const Voter1: address = @0x111;
    const Voter2: address = @0x222;
    const Voter3: address = @0x333;
    const Voter4: address = @0x444;
    const Voter5: address = @0x555;


    #[test]
    public fun initialize(): Scenario {
        let mut scenario = ts::begin(ORGANIZER);

        let projects = vector[
            Voter1,
            Voter2,
            Voter3,
            Voter4,
            Voter5,
        ];

        walrus_hackathon::init_for_test(scenario.ctx());

        ts::next_tx(&mut scenario, ORGANIZER);
        {
            let cap = ts::take_from_sender<OrganizerCap>(&scenario);
            let mut shortlisted = ts::take_from_sender<ShortListed>(&scenario);
            add_projects(&cap, &mut shortlisted, projects);
            scenario.return_to_sender<ShortListed>(shortlisted);
            scenario.return_to_sender<OrganizerCap>(cap);
        };

        scenario
    }

    #[test]
    public fun test_select_teams() {
        let mut scenario = initialize();
        ts::next_tx(&mut scenario, @0x0);
        {
            random::create_for_testing(scenario.ctx());
        };

        ts::next_tx(&mut scenario, @0x0);
        let mut random_state: Random = scenario.take_shared();
        {
            random_state.update_randomness_state_for_testing(
                0,
                x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
                scenario.ctx(),
            );
        };

        ts::next_tx(&mut scenario, ORGANIZER);
        {
            let cap = scenario.take_from_sender<OrganizerCap>();
            let mut shortlisted = ts::take_from_sender<ShortListed>(&scenario);

            select_teams(&random_state, &cap, &mut shortlisted, scenario.ctx());

            ts::return_shared<Random>(random_state);
            scenario.return_to_sender<OrganizerCap>(cap);
            scenario.return_to_sender<ShortListed>(shortlisted);
        };

        ts::next_tx(&mut scenario, ORGANIZER);
        {
            let shortlisted = ts::take_from_sender<ShortListed>(&scenario);
            shortlisted.team_polar_bear().do!(|polar_addr| {
                let polar_bear = scenario.take_from_address<TeamPolarBear>(polar_addr);
                ts::return_to_address(polar_addr, polar_bear);
            });
            shortlisted.team_orca().do!(|orca_addr| {
                let orca = scenario.take_from_address<TeamOrca>(orca_addr);
                ts::return_to_address(orca_addr, orca);
            });

            scenario.return_to_sender(shortlisted);

        };

        scenario.end();
    }
}
