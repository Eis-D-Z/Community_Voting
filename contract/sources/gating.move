module contract::walrus_hackathon;

use sui::vec_set::{Self,VecSet};
use sui::random::{Self,Random,RandomGenerator};

public struct ShortListed has key {
    id: UID,
    // If a team submitted 2 projects, they will need to provide different addresses
    // to be considered as 2 different teams
    projects: VecSet<address>,
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
    };
    transfer::share_object(short_listed);
}

public fun add_projects(_: &OrganizerCap, sl: &mut ShortListed, new_projects: vector<address>) {
    new_projects.do!(|project| {
        sl.projects.insert(project);
    });
}

entry fun select_teams(random: &Random, _: &OrganizerCap, sl: &ShortListed, ctx: &mut TxContext) {
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
            transfer::transfer(o, *projects.borrow(i));
        } else {
            let p = TeamPolarBear {
                id: object::new(ctx)
            };
            transfer::transfer(p, *projects.borrow(i));
        };

        i = i + 1;
    }
}

