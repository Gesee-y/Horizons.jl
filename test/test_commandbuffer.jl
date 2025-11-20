using Test

const BITBLOCK_SIZE = UInt128(32)
const BITBLOCK_MASK = (UInt128(1) << BITBLOCK_SIZE) - UInt128(1)
const COMMAND_ACTIONS = CRHorizons.COMMAND_ACTIONS

# Simuler la création de commandes avec leurs IDs

@commandaction DrawLine
@commandaction ClearBuffer
@commandaction DrawSprite

# Remplacer les appels `get_commandid` par la version simulée
CRHorizons.get_commandid(T::Type{<:CommandAction}) = T == DrawLine ? 1 :
                                        (T == ClearBuffer ? 2 :
                                        (T == DrawSprite ? 3 :
                                        error("get_commandid not defined for command type $T")))

CRHorizons.default_key(key::UInt128) = CRHorizons.decode_command(key)
CRHorizons.pass_order(ren=nothing) = (:render, :postprocess)

@testset "Encoding/Decoding Commands" begin
    target = 10; priority = 5; caller = 3; command_type = DrawLine
    encoded_key = CRHorizons.encode_command(command_type, target, priority, caller)
    decoded = CRHorizons.decode_command(encoded_key)

    @test decoded == (UInt128(target), UInt128(priority), UInt128(caller), UInt128(CRHorizons.get_commandid(command_type)))

    max_val = Int(BITBLOCK_MASK)
    target_max = max_val; priority_max = 1; caller_max = 1; command_max = length(COMMAND_ACTIONS)
    command_type_max = COMMAND_ACTIONS[command_max]

    encoded_max = CRHorizons.encode_command(command_type_max, target_max, priority_max, caller_max)
    decoded_max = CRHorizons.decode_command(encoded_max)

    @test decoded_max[1] == UInt128(target_max)
    @test decoded_max[2] == UInt128(priority_max)
    @test decoded_max[3] == UInt128(caller_max)
    @test decoded_max[4] == UInt128(command_max)

    target_zero = 0; priority_zero = 0; caller_zero = 0; command_type_zero = ClearBuffer
    encoded_zero = CRHorizons.encode_command(command_type_zero, target_zero, priority_zero, caller_zero)
    decoded_zero = CRHorizons.decode_command(encoded_zero)

    @test decoded_zero == (UInt128(0), UInt128(0), UInt128(0), UInt128(CRHorizons.get_commandid(command_type_zero)))

    @test CRHorizons.get_cmd_priority(encoded_key) == UInt128(priority)
end

@testset "Structure and Queries" begin
    
    @test_throws AssertionError RenderCommand{DrawLine}(Int(BITBLOCK_MASK) + 1, 1, 1) # Target hors limite
    @test_throws AssertionError RenderCommand{DrawLine}(1, Int(BITBLOCK_MASK) + 1, 1) # Priority hors limite
    
    cmd = RenderCommand{DrawLine}(10, 5, 3)
    @test cmd.target == 10
    @test typeof(cmd.commands) == Vector{DrawLine}
    @test isempty(cmd.commands)

    
    query_target = CommandQuery(target=10, priority=0, caller=0, commandid=0)
    
    target_mask = UInt128(BITBLOCK_MASK) << (BITBLOCK_SIZE*3)
    target_ref = UInt128(10) << (BITBLOCK_SIZE*3)
    @test query_target.mask == target_mask
    @test query_target.ref == target_ref

    query_complex = CommandQuery(priority=5, commandid=3)
    
    complex_mask = (UInt128(BITBLOCK_MASK) << (BITBLOCK_SIZE*2)) | UInt128(BITBLOCK_MASK)
    complex_ref = (UInt128(5) << (BITBLOCK_SIZE*2)) | UInt128(3)
    @test query_complex.mask == complex_mask
    @test query_complex.ref == complex_ref
end

@testset "CommandBuffer management" begin
    cb = CommandBuffer()
    @test haskey(cb.root.tree, :render)
    @test haskey(cb.root.tree, :postprocess)
    @test isempty(cb.root.tree[:render])

    cmd1 = DrawLine(); tid1 = 1; pid1 = 10; cid1 = 100
    cmd2 = DrawLine(); tid2 = 1; pid2 = 10; cid2 = 100
    cmd3 = ClearBuffer(); tid3 = 2; pid3 = 5; cid3 = 200 
    
    key1 = CRHorizons.encode_command(DrawLine, tid1, pid1, cid1)
    key3 = CRHorizons.encode_command(ClearBuffer, tid3, pid3, cid3)

    # Test CRHorizons.add_command!
    CRHorizons.add_command!(cb, tid1, pid1, cid1, cmd1)
    CRHorizons.add_command!(cb, tid2, pid2, cid2, cmd2)
    CRHorizons.add_command!(cb, tid3, pid3, cid3, cmd3)

    @test haskey(cb.root.tree[:render], key1)
    @test haskey(cb.root.tree[:render], key3)
    @test length(cb.root.tree[:render][key1].commands) == 2
    @test length(cb.root.tree[:render][key3].commands) == 1
    @test cb.root.tree[:render][key1].commands[1] === cmd1
    @test cb.root.tree[:render][key1].commands[2] === cmd2

    CRHorizons.clear!(cb)
    @test length(cb.root.tree[:render]) == 2
    @test isempty(cb.root.tree[:render][key1].commands)
    @test isempty(cb.root.tree[:render][key3].commands)

    CRHorizons.add_command!(cb, tid1, pid1, cid1, cmd1)
    r1 = cb.root.tree[:render][key1]
    
    remove_command!(cb, r1)
    @test !haskey(cb.root.tree[:render], key1)
    @test length(cb.root.tree[:render]) == 1
end

@testset "Sort and Iterators" begin
    cb = CommandBuffer()

    CRHorizons.add_command!(cb, 10, 5, 100, DrawLine())
    CRHorizons.add_command!(cb, 10, 1, 100, ClearBuffer())
    CRHorizons.add_command!(cb, 20, 5, 200, DrawLine())

    query = CommandQuery(target=10)
    results = CRHorizons.commands_iterator(cb, query)
    @test length(results) == 2
    priorities = [r.priority for r in results]
    @test all(p -> p == 5 || p == 1, priorities)

    query_line = CommandQuery(commandid=CRHorizons.get_commandid(DrawLine))
    results_line = CRHorizons.commands_iterator(cb, query_line)
    @test length(results_line) == 2
    
    query_exact = CommandQuery(target=10, priority=5, commandid=CRHorizons.get_commandid(DrawLine))
    results_exact = CRHorizons.commands_iterator(cb, query_exact)
    @test length(results_exact) == 1
    
    @test sort(CRHorizons.target_iterator(cb)) == [10, 20]
    @test sort(CRHorizons.priority_iterator(cb)) == [1, 5]
    @test sort(CRHorizons.caller_iterator(cb)) == [100, 200]
    @test sort(CRHorizons.commandid_iterator(cb)) == [CRHorizons.get_commandid(DrawLine), CRHorizons.get_commandid(ClearBuffer)]
    
    targets_priorities = CRHorizons.target_priority_iterator(cb)
    
    @test length(targets_priorities) == 3
    @test Set(targets_priorities) == Set([(10, 5), (10, 1), (20, 5)])

    
    sorted_groups = CRHorizons.sorted_command_groups(cb)
    
    priorities_default_sort = [g[2].priority for g in sorted_groups]
    @test priorities_default_sort == [1, 5, 5]

    
    sorted_by_priority = CRHorizons.sorted_command_bypriority(cb)
    
    p_by_priority = [CRHorizons.get_cmd_priority(g[1]) for g in sorted_by_priority]
    @test p_by_priority == [1, 5, 5]
    
    @test p_by_priority[1] == 1
end

@testset "Helper Functions" begin
    # Test add_pass
    cb = CommandBuffer()
    CRHorizons.add_pass(cb, "shadow_pass")
    @test haskey(cb.root.tree, :shadow_pass)
    @test isempty(cb.root.tree[:shadow_pass])

    @test pass_order(nothing) == (:render, :postprocess)
end