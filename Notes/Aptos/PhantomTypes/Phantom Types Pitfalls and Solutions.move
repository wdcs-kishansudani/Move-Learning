module phantom_pitfalls::common_mistakes {
    // ❌ PITFALL 1: Using phantom type in non-phantom position
    /* 
    struct BadExample<phantom T> {
        data: T  // ERROR: phantom T used in non-phantom position
    }
    */

    // ✅ SOLUTION 1: Proper phantom usage
    struct GoodExample<phantom T> {
        data: u64  // T is truly phantom - not used in fields
    }

    // ❌ PITFALL 2: Forgetting phantom keyword with unused type
    /*
    struct MissingPhantom<T> {  // T is unused but not marked phantom
        data: u64
    }
    // This compiles but has unnecessary ability constraints
    */

    // ✅ SOLUTION 2: Mark unused types as phantom
    struct ProperPhantom<phantom T> {
        data: u64
    }

    // ❌ PITFALL 3: Mixing phantom and non-phantom incorrectly
    /*
    struct NonPhantomWrapper<T> {
        value: T
    }
    
    struct BadMixing<phantom T> {
        wrapper: NonPhantomWrapper<T>  // ERROR: T appears in non-phantom position
    }
    */

    // ✅ SOLUTION 3: Ensure phantom types only appear in phantom positions
    struct PhantomWrapper<phantom T> {
        value: u64
    }
    
    struct GoodMixing<phantom T> {
        wrapper: PhantomWrapper<T>  // OK: T still in phantom position
    }

    // ❌ PITFALL 4: Ability constraint confusion
    struct NoCopyType {}
    
    /*
    fun bad_function() {
        let coin1 = GoodExample<NoCopyType> { data: 100 };
        let coin2 = copy coin1;  // Might expect this to fail, but it works!
    }
    */

    // ✅ SOLUTION 4: Understanding ability derivation with phantom types
    fun demonstrate_ability_derivation() {
        // Even though NoCopyType has no copy ability,
        // GoodExample<NoCopyType> has copy because:
        // 1. GoodExample is declared with copy
        // 2. Phantom type arguments don't affect ability derivation
        let coin1 = GoodExample<NoCopyType> { data: 100 };
        let coin2 = copy coin1;  // This works!
        
        // Clean up
        let GoodExample { data: _ } = coin1;
        let GoodExample { data: _ } = coin2;
    }

    // ❌ PITFALL 5: Phantom type constraint violations
    /*
    struct ConstraintViolation<phantom T: copy> {}
    
    fun bad_instantiation() {
        // This should fail because NoCopyType doesn't have copy
        let bad = ConstraintViolation<NoCopyType> {};
    }
    */

    // ✅ SOLUTION 5: Respect phantom type constraints
    struct CopyType has copy, drop {}
    struct ProperConstraint<phantom T: copy> has copy, drop {}
    
    fun good_instantiation() {
        let good = ProperConstraint<CopyType> {};
        let ProperConstraint {} = good;
    }

    // ❌ PITFALL 6: Over-engineering with phantom types
    /*
    struct OverEngineered<
        phantom StateType,
        phantom PermissionType, 
        phantom ValidationLevel,
        phantom AuditLevel
    > {
        data: u64
    }
    // Too many phantom types make code hard to understand and use
    */

    // ✅ SOLUTION 6: Use phantom types judiciously
    struct WellDesigned<phantom Purpose> {
        data: u64
    }
    
    // Specific purpose types
    struct Authentication {}
    struct Authorization {}
    struct DataStorage {}

    // ❌ PITFALL 7: Phantom type witness confusion
    struct BadWitness<phantom T> has copy, drop {}
    
    /*
    // Anyone can create this witness - defeats the purpose
    public fun create_bad_witness<T>(): BadWitness<T> {
        BadWitness<T> {}
    }
    */

    // ✅ SOLUTION 7: Proper witness pattern
    struct GoodWitness<phantom T> has copy, drop {
        // Private fields or implementation details
        _private: bool
    }
    
    // Only this module can create witnesses for types it defines
    public(package) fun create_witness<T>(): GoodWitness<T> {
        GoodWitness<T> { _private: true }
    }

    // ❌ PITFALL 8: Phantom recursive types (if they were allowed)
    /*
    // This would be invalid even if Move allowed it
    struct BadRecursive<phantom T> {
        next: BadRecursive<BadRecursive<T>>  // Infinite type expansion
    }
    */

    // ✅ SOLUTION 8: Use bounded recursion or alternative patterns
    struct GoodRecursive<phantom T> {
        depth: u8,  // Bound the recursion
        data: u64
    }

    // Advanced: Type-safe builder pattern
    struct Builder<phantom Stage> has drop {
        data: u64,
        config: u64,
    }

    struct StageOne {}
    struct StageTwo {}  
    struct Complete {}

    public fun new_builder(): Builder<StageOne> {
        Builder<StageOne> { data: 0, config: 0 }
    }

    public fun set_data(builder: Builder<StageOne>, data: u64): Builder<StageTwo> {
        Builder<StageTwo> { data, config: builder.config }
    }

    public fun set_config(builder: Builder<StageTwo>, config: u64): Builder<Complete> {
        Builder<Complete> { data: builder.data, config }
    }

    public fun build(builder: Builder<Complete>): GoodExample<Complete> {
        let Builder { data, config: _ } = builder;
        GoodExample<Complete> { data }
    }

    // Performance consideration: Zero-cost abstractions
    public fun demonstrate_zero_cost() {
        // All these have identical runtime representation
        let ex1 = GoodExample<Authentication> { data: 42 };
        let ex2 = GoodExample<Authorization> { data: 42 };
        let ex3 = GoodExample<DataStorage> { data: 42 };
        
        // But they're different types at compile time
        // This would not compile: ex1 = ex2;
        
        // Runtime cost is identical to:
        let plain = PlainStruct { data: 42 };
        
        // Cleanup
        let GoodExample { data: _ } = ex1;
        let GoodExample { data: _ } = ex2;
        let GoodExample { data: _ } = ex3;
        let PlainStruct { data: _ } = plain;
    }

    struct PlainStruct has drop {
        data: u64
    }

    #[test]
    fun test_proper_usage() {
        demonstrate_ability_derivation();
        good_instantiation();
        demonstrate_zero_cost();

        // Test builder pattern
        let result = new_builder()
            |> set_data(100)
            |> set_config(200)
            |> build();
        
        assert!(result.data == 100, 1);
        let GoodExample { data: _ } = result;
    }

    // Documentation: When to use phantom types
    /*
    Use phantom types when you need:
    
    1. ✅ Type-safe resource management (currencies, permissions)
    2. ✅ Compile-time state tracking (state machines, builders)
    3. ✅ Witness patterns for authorization
    4. ✅ Zero-cost type distinctions
    5. ✅ Generic libraries with type safety
    
    Don't use phantom types when:
    
    1. ❌ You actually need the type parameter in struct fields
    2. ❌ Runtime type information is needed
    3. ❌ Simple enums would be clearer
    4. ❌ Over-engineering simple problems
    5. ❌ You need reflection or dynamic typing
    */
}