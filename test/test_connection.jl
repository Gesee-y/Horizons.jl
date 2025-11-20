
# ------------------------------------------------
# 1. Line Tests
# ------------------------------------------------

@testset "Line Structure and Conversion Tests" begin
    # Test 1.1: Line constructor check
    l = Line(10, 20)
    @test l isa AbstractConnection
    @test l.data == (UInt32(10), UInt32(20))

    # Test 1.2: to_array conversion
    @test to_array(l) == UInt32[10, 20]

    # Test 1.3: isequal function
    l2 = Line(10, 20)
    l3 = Line(20, 10) # Different order
    @test isequal(l, l2) == true
    @test isequal(l, l3) == false
end

# ------------------------------------------------
# 2. Triangle (Tri) Tests
# ------------------------------------------------

@testset "Tri Structure and Conversion Tests" begin
    # Test 2.1: Tri constructor check (vertices: 1, 2, 3)
    t = Tri(1, 2, 3)
    @test t isa AbstractConnection
    @test t.data isa NTuple{3,Line}

    # Verify internal lines (l1=(1,2), l2=(1,3), l3=(2,3))
    @test t.data[1] == Line(1, 2)
    @test t.data[2] == Line(1, 3)
    @test t.data[3] == Line(2, 3)

    # Test 2.2: to_array conversion
    # The current implementation returns: 
    # [data[1].data[1], data[1].data[2], data[2].data[2]]
    # which is: [Line(1,2).data[1], Line(1,2).data[2], Line(1,3).data[2]] -> [1, 2, 3]
    @test to_array(t) == UInt32[1, 2, 3]
    
    # Test 2.3: isequal function
    t2 = Tri(1, 2, 3)
    t3 = Tri(1, 3, 2) # Different line order
    @test isequal(t, t2) == true
    @test isequal(t, t3) == false # Internal lines will be different
end

# ------------------------------------------------
# 3. Face Tests
# ------------------------------------------------

@testset "Face Structure and Conversion Tests" begin
    # Test 3.1: 3-vertex Face (Alias for Tri)
    f_tri = Face(1, 2, 3)
    @test f_tri isa Tri # It returns a Tri, not a Face struct
    @test to_array(f_tri) == UInt32[1, 2, 3]

    # Test 3.2: 4-vertex Face constructor check (Quad: 1, 2, 3, 4)
    f_quad = Face(1, 2, 3, 4)
    @test f_quad isa AbstractConnection
    @test f_quad.data isa NTuple{2,Tri}

    # Verify internal triangles (t1 = Tri(1,2,3), t2 = Tri(1,3,4))
    t1_expected = Tri(1, 2, 3)
    t2_expected = Tri(1, 3, 4)
    @test f_quad.data[1] == t1_expected
    @test f_quad.data[2] == t2_expected

    # Test 3.3: to_array conversion for 4-vertex Face
    # It should be append!(to_array(t1), to_array(t2))
    # to_array(t1) = [1, 2, 3]
    # to_array(t2) = [1, 3, 4]
    @test to_array(f_quad) == UInt32[1, 2, 3, 1, 3, 4]

    # Test 3.4: isequal function for 4-vertex Face
    f_quad2 = Face(1, 2, 3, 4)
    f_quad3 = Face(1, 3, 2, 4) # Different triangle division
    @test isequal(f_quad, f_quad2) == true
    @test isequal(f_quad, f_quad3) == false 
end