use starknet::SyscallResult;

use dojo::{
    world::{IWorldDispatcher, IWorldDispatcherTrait}, utils::{Descriptor, DescriptorTrait},
    meta::{Layout, introspect::Ty}, model::{ModelDefinition, ModelIndex},
    utils::{entity_id_from_key, serialize_inline, deserialize_unwrap, entity_id_from_keys}
};

#[derive(Drop)]
pub enum Index<T> {
    Key: T,
    Id: felt252
}

pub trait IndexParser<M, K, +Serde<K>> {
    fn key(self: @M) -> K;

    fn entity_id(self: @M) -> felt252 {
        entity_id_from_key(@Self::key(self))
    }
}

pub fn to_entity_id<K, +Serde<K>>(self: @Index<K>) -> felt252 {
    match self {
        Index::Key(key) => dojo::utils::entity_id_from_key(key),
        Index::Id(id) => *id
    }
}

fn to_model_index<K, +Serde<K>>(self: @Index<K>) -> ModelIndex {
    match self {
        Index::Key(key) => ModelIndex::Keys(dojo::utils::serialize_inline(key)),
        Index::Id(id) => ModelIndex::Id(*id),
    }
}

pub trait DojoSerde<T, +Serde<T>> {    
    fn serialize_keys(self: @T) -> Span<felt252>;
    fn serialize_values(self: @T) -> Span<felt252>;

    fn deserialize(ref serialized_keys: Span<felt252>, ref serialized_values: Span<felt252>) -> Option<T> {
        let mut serialized: Array<felt252> = serialized_keys.into();
        serialized.append_span(serialized_values);
        let mut span = serialized.span();

        Serde::<T>::deserialize(ref span)
    }
}

pub trait Model<M, K, E> {
    fn get(self: @IWorldDispatcher, key: K) -> M;
    fn get_entity(self: @IWorldDispatcher, index: Index<K>) -> E;

    fn set(self: IWorldDispatcher, model: @M);
    fn update(self: IWorldDispatcher, entity: @E);

    fn delete(self: IWorldDispatcher, model: @M);
    fn delete_entity(self: IWorldDispatcher, entity: @E);
    fn delete_from_index(self: IWorldDispatcher, index: Index<K>);

    fn update_serialized_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
        values: Span<felt252>,
    );

    fn get_serialized_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
    ) -> Span<felt252>;
}

pub impl ModelImpl<
M, K, E, +ModelDefinition<M>, +Serde<M>, +DojoSerde<M>, +Drop<K>, +Serde<K>, +Serde<E>, +DojoSerde<E>
> of Model<M, K, E> {

    fn get(self: @IWorldDispatcher, key: K) -> M {
        let mut serialized_keys = dojo::utils::serialize_inline(@key);
        let mut serialized_values = IWorldDispatcherTrait::entity(
            *self,
            ModelDefinition::<M>::selector(),
            ModelIndex::Keys(serialized_keys),
            ModelDefinition::<M>::layout()
        );

        match DojoSerde::deserialize(ref serialized_keys, ref serialized_values) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Model: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                )
            }
        }
    }

    fn get_entity(self: @IWorldDispatcher, index: Index<K>) -> E {
        let model_index = to_model_index(@index);
        let entity_id = match index {
            Index::Key(key) => entity_id_from_key(@key),
            Index::Id(id) => id
        };

        let mut serialized_keys = [entity_id].span();
        let mut serialized_values = IWorldDispatcherTrait::entity(
            *self,
            ModelDefinition::<M>::selector(),
            model_index,
            ModelDefinition::<M>::layout()
            );

        match DojoSerde::deserialize(ref serialized_keys, ref serialized_values) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Entity: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                )
            }
        }
    }

    fn set(self: IWorldDispatcher, model: @M) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelDefinition::<M>::selector(),
            ModelIndex::Keys(DojoSerde::<M>::serialize_keys(model)),
            DojoSerde::<M>::serialize_values(model),
            ModelDefinition::<M>::layout()
        );
    }

    fn update(self: IWorldDispatcher, entity: @E) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelDefinition::<M>::selector(),
            ModelIndex::Keys(DojoSerde::<E>::serialize_keys(entity)),
            DojoSerde::<E>::serialize_values(entity),
            ModelDefinition::<M>::layout()
        );
    }

    fn delete(self: IWorldDispatcher, model: @M) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelDefinition::<M>::selector(),
            ModelIndex::Keys(DojoSerde::<M>::serialize_keys(model)),
            ModelDefinition::<M>::layout()
        );
    }

    fn delete_entity(self: IWorldDispatcher, entity: @E) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelDefinition::<M>::selector(),
            ModelIndex::Keys(DojoSerde::<E>::serialize_keys(entity)),
            ModelDefinition::<M>::layout()
        );
    }

    fn delete_from_index(self: IWorldDispatcher, index: Index<K>) {
        let model_index = to_model_index(@index);
        
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelDefinition::<M>::selector(),
            model_index,
            ModelDefinition::<M>::layout()
        );
    }

    fn update_serialized_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
        values: Span<felt252>,
    ) {
        match dojo::utils::find_model_field_layout(ModelDefinition::<M>::layout(), member_id) {
            Option::Some(field_layout) => {
                IWorldDispatcherTrait::set_entity(
                    world, ModelDefinition::<M>::selector(), ModelIndex::MemberId((entity_id, member_id)), values, field_layout,
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    fn get_serialized_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
    ) -> Span<felt252> {
        match dojo::utils::find_model_field_layout(ModelDefinition::<M>::layout(), member_id) {
            Option::Some(field_layout) => {
                IWorldDispatcherTrait::entity(
                    world, ModelDefinition::<M>::selector(), ModelIndex::MemberId((entity_id, member_id)), field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }
}
