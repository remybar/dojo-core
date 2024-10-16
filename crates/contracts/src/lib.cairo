pub mod contract {
    pub mod contract;
    pub use contract::{IContract, IContractDispatcher, IContractDispatcherTrait};

    pub mod components {
        pub mod upgradeable;
        pub mod world_provider;
    }
}

pub mod event {
    pub mod event;
    pub use event::{Event, IEvent, IEventDispatcher, IEventDispatcherTrait};

    #[cfg(target: "test")]
    pub use event::{EventTest};
}

pub mod meta {
    pub mod introspect;
    pub use introspect::Introspect;

    pub mod layout;
    pub use layout::{Layout, FieldLayout};
}

pub mod model {
    pub mod definition;
    pub use definition::{ModelIndex, ModelDefinition};

    pub mod model;
    pub use model::{Model, Index, ModelImpl, IndexParser, DojoSerde, to_entity_id};

    pub mod interface;
    pub use interface::{IModel, IModelDispatcher, IModelDispatcherTrait};

    pub mod metadata;
    pub use metadata::{ResourceMetadata, ResourceMetadataModel, resource_metadata};
    pub(crate) use metadata::{initial_address, initial_class_hash};
}

pub(crate) mod storage {
    pub(crate) mod database;
    pub(crate) mod packing;
    pub(crate) mod layout;
    pub(crate) mod storage;
    pub(crate) mod entity_model;
}

pub mod utils {
    // Since Scarb 2.6.0 there's an optimization that does not
    // build tests for dependencies and it's not configurable.
    //
    // To expose correctly the test utils for a package using dojo-core,
    // we need to it in the `lib` target or using the `#[cfg(target: "test")]`
    // attribute.
    //
    // Since `test_utils` is using `TEST_CLASS_HASH` to factorize some deployment
    // core, we place it under the test target manually.
    #[cfg(target: "test")]
    pub mod test;

    pub mod utils;
    pub use utils::{
        bytearray_hash, entity_id_from_keys, find_field_layout, find_model_field_layout, any_none,
        sum, combine_key, selector_from_names, serialize_inline, deserialize_unwrap,
        entity_id_from_key
    };

    pub mod descriptor;
    pub use descriptor::{
        Descriptor, DescriptorTrait, IDescriptorDispatcher, IDescriptorDispatcherTrait
    };
}

pub mod world {
    pub(crate) mod errors;

    mod resource;
    pub use resource::{Resource, ResourceIsNoneTrait};

    mod iworld;
    pub use iworld::{
        IWorld, IWorldDispatcher, IWorldDispatcherTrait, IUpgradeableWorld,
        IUpgradeableWorldDispatcher, IUpgradeableWorldDispatcherTrait
    };

    #[cfg(target: "test")]
    pub use iworld::{IWorldTest, IWorldTestDispatcher, IWorldTestDispatcherTrait};

    mod world_contract;
    pub use world_contract::world;
}
