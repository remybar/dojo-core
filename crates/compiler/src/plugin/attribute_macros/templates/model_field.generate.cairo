fn get_$field_name$(self: @dojo::world::IWorldDispatcher, key: $model_type$KeyType) -> $field_type$ {
    dojo::utils::deserialize_unwrap::<$field_type$>(
        dojo::model::ModelImpl::<$model_type$, $model_type$KeyType, $model_type$Entity>::get_serialized_member(
            *self,
            dojo::utils::entity_id_from_key(@key),
            $field_selector$,
        )
    )
}

fn get_$field_name$_from_index(self: @dojo::world::IWorldDispatcher, index: Index<$model_type$KeyType>) -> $field_type$ {
    dojo::utils::deserialize_unwrap::<$field_type$>(
        dojo::model::ModelImpl::<$model_type$, $model_type$KeyType, $model_type$Entity>::get_serialized_member(
            *self,
            dojo::model::to_entity_id(@index),
            $field_selector$,
        )
    )
}

fn update_$field_name$(self: dojo::world::IWorldDispatcher, key: $model_type$KeyType, value: $field_type$) {
    dojo::model::ModelImpl::<$model_type$, $model_type$KeyType, $model_type$Entity>::update_serialized_member(
        self,
        dojo::utils::entity_id_from_key(@key),
        $field_selector$,
        dojo::utils::serialize_inline::<$field_type$>(@value)
    )
}

fn update_$field_name$_from_index(self: dojo::world::IWorldDispatcher, index: Index<$model_type$KeyType>, value: $field_type$) {
    dojo::model::ModelImpl::<$model_type$, $model_type$KeyType, $model_type$Entity>::update_serialized_member(
        self,
        dojo::model::to_entity_id(@index),
        $field_selector$,
        dojo::utils::serialize_inline::<$field_type$>(@value)
    )
}

