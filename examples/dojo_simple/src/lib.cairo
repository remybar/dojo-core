pub mod models {
    use starknet::ContractAddress;

    #[derive(Drop, Serde)]
    #[dojo::model]
    pub struct Attack {
        #[key]
        pub player: ContractAddress,
        #[key]
        pub monster_id: u32,
        pub damage: u32,
        pub effect: u32,
    }
}

#[dojo::interface]
pub trait IActions {
    fn spawn(ref world: IWorldDispatcher);
}

#[dojo::contract]
pub mod actions {
    use dojo::model::{Index};
    use dojo::utils::entity_id_from_keys;
    use super::{
        IActions,
        models::{Attack, AttackModel},
    };

    #[constructor]
    fn constructor(ref self: ContractState, a: u32) {
        let _b = a + 1;
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(ref world: IWorldDispatcher) {
            let caller = starknet::get_caller_address();

            let key = (caller, 12);

            let attack = AttackModel::get(@world, key);
            let attack_entity = AttackModel::get_entity(@world, Index::Id(42));
            let _ = AttackModel::get_entity(@world, Index::Key(key));

            AttackModel::set(world, @attack);
            AttackModel::update(world, @attack_entity);

            AttackModel::delete(world, @attack);
            AttackModel::delete_entity(world, @attack_entity);

            AttackModel::delete_from_index(world, Index::Id(42));
            AttackModel::delete_from_index(world, Index::Key(key));

            let _ = AttackModel::get_damage(world, key);
            let _ = AttackModel::get_damage_from_index(world, Index::id(42));
            let _ = AttackModel::get_damage_from_index(world, Index::Key(key));
        }
    }
}
