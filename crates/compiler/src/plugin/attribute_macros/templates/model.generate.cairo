$derive_entity$
pub struct $model_type$Entity {
    __id: felt252, // private field
    $members_values$
} 

pub type $model_type$KeyType = $key_type$;

pub impl $model_type$IndexParser of dojo::model::IndexParser<$model_type$, $key_type$> {
    fn key(self: @$model_type$) -> $key_type$ {
        $keys_to_tuple$
    }
}

// Impl to get the static definition of a model
pub impl $model_type$Definition of dojo::model::ModelDefinition<$model_type$>{
    #[inline(always)]
    fn version() -> u8 {
        $model_version$
    }
    
    #[inline(always)]
    fn selector() -> felt252 {
        $model_selector$
    }
    
    #[inline(always)]
    fn name_hash() -> felt252 {
        $model_name_hash$
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        $model_namespace_hash$
    }

    #[inline(always)]
    fn name() -> ByteArray {
        "$model_type$"
    }
    
    #[inline(always)]
    fn namespace() -> ByteArray {
        "$model_namespace$"
    }
    
    #[inline(always)]
    fn tag() -> ByteArray {
        "$model_tag$"
    }

    #[inline(always)]
    fn layout() -> dojo::meta::Layout {
        dojo::meta::Introspect::<$model_type$>::layout()
    }
}

pub impl $model_type$DojoSerde of dojo::model::DojoSerde<$model_type$>{
    fn serialize_keys(self: @$model_type$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }
    fn serialize_values(self: @$model_type$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
} 

pub impl $model_type$EntityDojoSerde of dojo::model::DojoSerde<$model_type$Entity>{
    fn serialize_keys(self: @$model_type$Entity) -> Span<felt252> {
        [*self.__id].span()
    }
    fn serialize_values(self: @$model_type$Entity) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
} 

pub impl $model_type$Model = dojo::model::ModelImpl<$model_type$, $key_type$, $model_type$Entity>;

#[generate_trait]
pub impl $model_type$Members of $model_type$MembersStore {
$field_accessors$
}

#[starknet::interface]
pub trait I$model_type$<T> {
    fn ensure_abi(self: @T, model: $model_type$);
}

#[starknet::contract]
pub mod $model_type_snake$ {
    use super::$model_type$;
    use super::I$model_type$;
    use super::$model_type$Definition;
    use super::$model_type$Model;
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl of dojo::model::IModel<ContractState>{
        fn name(self: @ContractState) -> ByteArray {
            $model_type$Definition::name()
        }

        fn namespace(self: @ContractState) -> ByteArray {
            $model_type$Definition::namespace()
        }

        fn tag(self: @ContractState) -> ByteArray {
            $model_type$Definition::tag()
        }

        fn version(self: @ContractState) -> u8 {
            $model_type$Definition::version()
        }

        fn selector(self: @ContractState) -> felt252 {
            $model_type$Definition::selector()
        }

        fn name_hash(self: @ContractState) -> felt252 {
            $model_type$Definition::name_hash()
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            $model_type$Definition::namespace_hash()
        }

        fn unpacked_size(self: @ContractState) -> Option<usize> {
            dojo::meta::Introspect::<$model_type$>::size()
        }

        fn packed_size(self: @ContractState) -> Option<usize> {
            dojo::meta::layout::compute_packed_size($model_type$Definition::layout())
        }

        fn layout(self: @ContractState) -> dojo::meta::Layout {
            $model_type$Definition::layout()
        }

        fn schema(self: @ContractState) -> dojo::meta::introspect::Ty {
            dojo::meta::Introspect::<$model_type$>::ty()
        }
    }

    #[abi(embed_v0)]
    impl $model_type$Impl of I$model_type$<ContractState>{
        fn ensure_abi(self: @ContractState, model: $model_type$) {
        }
    }
}