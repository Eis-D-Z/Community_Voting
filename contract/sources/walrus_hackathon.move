module contract::walrus_hackathon;

use sui::vec_set::{Self,VecSet};
use sui::random::{Random};

public struct ShortListed has key {
    id: UID,
    // If a team submitted 2 projects, they will need to provide different addresses
    // to be considered as 2 different teams
    projects: VecSet<address>,
    team_orca: vector<address>,
    team_polar_bear: vector<address>,
}

public struct TeamPolarBear has key {
    id: UID
}

public struct TeamOrca has key {
    id: UID
}

public struct OrganizerCap has key, store {
    id: UID
}

fun init(ctx: &mut TxContext) {
    let cap = OrganizerCap {
        id: object::new(ctx)
    };
    transfer::public_transfer(cap, ctx.sender());
    let short_listed = ShortListed {
        id: object::new(ctx),
        projects: vec_set::empty(),
        team_orca: vector[],
        team_polar_bear: vector[],
    };
    transfer::transfer(short_listed, ctx.sender());
}

public fun add_projects(_: &OrganizerCap, sl: &mut ShortListed, new_projects: vector<address>) {
    new_projects.do!(|project| {
        sl.projects.insert(project);
    });
}

public fun team_orca(self: &ShortListed): vector<address> {
    self.team_orca
}

public fun team_polar_bear(self: &ShortListed): vector<address> {
    self.team_polar_bear
}

entry fun select_teams(random: &Random, _: &OrganizerCap, sl: &mut ShortListed, ctx: &mut TxContext) {
    let mut rng = random.new_generator(ctx);
    let mut projects = sl.projects.into_keys();
    rng.shuffle(&mut projects);
    // divide the projects into 2 teams
    // if the number of projects is odd, the first team will have 1 more project
    let n = projects.length();
    let n1 = n / 2;
    let mut i = 0;
    while (i < projects.length()) {
        if (i >= n1) {
            let o = TeamOrca {
                id: object::new(ctx)
            };
            sl.team_orca.push_back(*projects.borrow(i));
            transfer::transfer(o, *projects.borrow(i));
        } else {
            let p = TeamPolarBear {
                id: object::new(ctx)
            };
            sl.team_polar_bear.push_back(*projects.borrow(i));
            transfer::transfer(p, *projects.borrow(i));
        };

        i = i + 1;
    }
}

#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(ctx);
}

