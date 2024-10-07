//! Test some manually expanded code for permissioned contract deployment and resource registration.
//!

#[starknet::contract]
pub mod attacker_contract {
    use dojo::world;
    use dojo::world::IWorldDispatcher;
    use dojo::world::IWorldDispatcherTrait;
    use dojo::components::world_provider::{IWorldProvider, WorldProviderComponent};
    use dojo::components::upgradeable::upgradeable;
    use dojo::contract::IContract;
    use starknet::storage::{
        StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };

    component!(path: WorldProviderComponent, storage: world_provider, event: WorldProviderEvent);
    component!(path: upgradeable, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl WorldProviderImpl =
        WorldProviderComponent::WorldProviderImpl<ContractState>;
    impl WorldProviderInternalImpl = WorldProviderComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradableImpl = upgradeable::UpgradableImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        WorldProviderEvent: WorldProviderComponent::Event,
        UpgradeableEvent: upgradeable::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        world_provider: dojo::components::world_provider::WorldProviderComponent::Storage,
        #[substorage(v0)]
        upgradeable: dojo::components::upgradeable::upgradeable::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.world_provider.initializer();
    }

    #[abi(embed_v0)]
    pub impl ContractImpl of IContract<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "test_1"
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "ns1"
        }

        fn tag(self: @ContractState) -> ByteArray {
            "other tag"
        }

        fn name_hash(self: @ContractState) -> felt252 {
            'name hash'
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@"atk")
        }

        fn selector(self: @ContractState) -> felt252 {
            // Targetting a resource that exists in an other namespace.
            selector_from_tag!("dojo-Foo")
        }
    }
}

#[starknet::contract]
pub mod attacker_model {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl of dojo::model::IModel<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "m1"
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "ns1"
        }

        fn tag(self: @ContractState) -> ByteArray {
            "other tag"
        }

        fn version(self: @ContractState) -> u8 {
            1
        }

        fn selector(self: @ContractState) -> felt252 {
            // Targetting a resource that exists in an other namespace.
            selector_from_tag!("dojo-Foo")
        }

        fn name_hash(self: @ContractState) -> felt252 {
            'name hash'
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@"atk")
        }

        fn unpacked_size(self: @ContractState) -> Option<usize> {
            Option::None
        }

        fn packed_size(self: @ContractState) -> Option<usize> {
            Option::None
        }

        fn layout(self: @ContractState) -> dojo::model::Layout {
            dojo::model::Layout::Fixed([].span())
        }

        fn schema(self: @ContractState) -> dojo::model::introspect::ModelTy {
            dojo::model::introspect::ModelTy { name: 'm1', attrs: [].span(), children: [].span() }
        }
    }
}
