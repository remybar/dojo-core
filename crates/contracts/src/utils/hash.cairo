use core::poseidon::poseidon_hash_span;
use core::serde::Serde;

/// Compute the poseidon hash of a serialized ByteArray
pub fn bytearray_hash(data: @ByteArray) -> felt252 {
    let mut serialized = ArrayTrait::new();
    Serde::serialize(data, ref serialized);
    poseidon_hash_span(serialized.span())
}

/// Computes the selector of a resource from the namespace and the name.
pub fn selector_from_names(namespace: @ByteArray, name: @ByteArray) -> felt252 {
    poseidon_hash_span([bytearray_hash(namespace), bytearray_hash(name)].span())
}
