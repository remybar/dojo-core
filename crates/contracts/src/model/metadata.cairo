//! ResourceMetadata model.
//!
//! Manually expand to ensure that dojo-core
//! does not depend on dojo plugin to be built.
//!
use core::array::ArrayTrait;
use core::byte_array::ByteArray;
use core::poseidon::poseidon_hash_span;
use core::serde::Serde;

use dojo::model::{ModelIndex, ModelImpl, IndexParser, DojoSerde};
use dojo::meta::introspect::{Introspect, Ty, Struct, Member};
use dojo::meta::{Layout, FieldLayout};
use dojo::utils;
use dojo::utils::{serialize_inline};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

pub fn initial_address() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

pub fn initial_class_hash() -> starknet::ClassHash {
    starknet::class_hash::class_hash_const::<
        0x03f75587469e8101729b3b02a46150a3d99315bc9c5026d64f2e8a061e413255
    >()
}

#[derive(Drop, Serde, PartialEq, Clone, Debug)]
pub struct ResourceMetadata {
    // #[key]
    pub resource_id: felt252,
    pub metadata_uri: ByteArray,
}

#[derive(Drop, Serde, PartialEq, Clone, Debug)]
pub struct ResourceMetadataEntity {
    pub __id: felt252,
    pub metadata_uri: ByteArray,
}

pub impl ResourceMetadataDefinitionImpl of dojo::model::ModelDefinition<ResourceMetadata> {
    #[inline(always)]
    fn name() -> ByteArray {
        "ResourceMetadata"
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        "__DOJO__"
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        "__DOJO__-ResourceMetadata"
    }

    #[inline(always)]
    fn version() -> u8 {
        1
    }

    #[inline(always)]
    fn selector() -> felt252 {
        poseidon_hash_span([Self::namespace_hash(), Self::name_hash()].span())
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        utils::bytearray_hash(@Self::name())
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        utils::bytearray_hash(@Self::namespace())
    }

    #[inline(always)]
    fn layout() -> Layout {
        Introspect::<ResourceMetadata>::layout()
    }
}

pub impl ResourceMetadataIndexParser of IndexParser<ResourceMetadata, felt252> {
    fn key(self: @ResourceMetadata) -> felt252 {
        *self.resource_id
    }

    // TODO RBA: why ?
    fn entity_id(self: @ResourceMetadata) -> felt252 {
        dojo::utils::entity_id_from_key(@Self::key(self))
    }
}

pub impl ResourceMetadataDojoSerdeImpl of DojoSerde<ResourceMetadata> {
    fn serialize_keys(self: @ResourceMetadata) -> Span<felt252> {
        [*self.resource_id].span()
    }
    fn serialize_values(self: @ResourceMetadata) -> Span<felt252> {
        serialize_inline(self.metadata_uri)
    }
}

pub impl ResourceMetadataEntityDojoSerdeImpl of DojoSerde<ResourceMetadataEntity> {
    fn serialize_keys(self: @ResourceMetadataEntity) -> Span<felt252> {
        [*self.__id].span()
    }
    fn serialize_values(self: @ResourceMetadataEntity) -> Span<felt252> {
        serialize_inline(self.metadata_uri)
    }
}

pub impl ResourceMetadataModel = ModelImpl<ResourceMetadata, felt252, ResourceMetadataEntity>;

pub impl ResourceMetadataIntrospect<> of Introspect<ResourceMetadata<>> {
    #[inline(always)]
    fn size() -> Option<usize> {
        Option::None
    }

    #[inline(always)]
    fn layout() -> Layout {
        Layout::Struct(
            [FieldLayout { selector: selector!("metadata_uri"), layout: Layout::ByteArray }].span()
        )
    }

    #[inline(always)]
    fn ty() -> Ty {
        Ty::Struct(
            Struct {
                name: 'ResourceMetadata', attrs: [].span(), children: [
                    Member {
                        name: 'resource_id', ty: Ty::Primitive('felt252'), attrs: ['key'].span()
                    },
                    Member { name: 'metadata_uri', ty: Ty::ByteArray, attrs: [].span() }
                ].span()
            }
        )
    }
}

#[starknet::contract]
pub mod resource_metadata {
    use super::{ResourceMetadata, ResourceMetadataDefinitionImpl};

    use dojo::meta::introspect::{Introspect, Ty};
    use dojo::meta::Layout;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn selector(self: @ContractState) -> felt252 {
        ResourceMetadataDefinitionImpl::selector()
    }

    fn name(self: @ContractState) -> ByteArray {
        ResourceMetadataDefinitionImpl::name()
    }

    fn version(self: @ContractState) -> u8 {
        ResourceMetadataDefinitionImpl::version()
    }

    fn namespace(self: @ContractState) -> ByteArray {
        ResourceMetadataDefinitionImpl::namespace()
    }

    #[external(v0)]
    fn unpacked_size(self: @ContractState) -> Option<usize> {
        Introspect::<ResourceMetadata>::size()
    }

    #[external(v0)]
    fn packed_size(self: @ContractState) -> Option<usize> {
        dojo::meta::layout::compute_packed_size(Introspect::<ResourceMetadata>::layout())
    }

    #[external(v0)]
    fn layout(self: @ContractState) -> Layout {
        Introspect::<ResourceMetadata>::layout()
    }

    #[external(v0)]
    fn schema(self: @ContractState) -> Ty {
        Introspect::<ResourceMetadata>::ty()
    }

    #[external(v0)]
    fn ensure_abi(self: @ContractState, model: ResourceMetadata) {}
}
