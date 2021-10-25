using TensorNetworkCodes
using TensorNetworkCodes: _find_product_indices
using LinearAlgebra: I
using Test

@testset "find_distance_logicals" begin
    d, ls = find_distance_logicals(five_qubit_code())
    @test d == 3 && all(==(3), (pauli_weight(l) for l in ls))

    d, ls = find_distance_logicals(steane_code())
    @test d == 3 && all(==(3), (pauli_weight(l) for l in ls))

    d, ls = find_distance_logicals(five_qubit_surface_code())
    @test d == 2 && all(==(2), (pauli_weight(l) for l in ls))

    @test_throws ErrorException find_distance_logicals(five_qubit_code(); max_distance=2)
end

@testset "_find_product_indices" begin
    operators = [[1, 3, 3, 1, 0], [0, 1, 3, 3, 1], [1, 0, 1, 3, 3], [3, 1, 0, 1, 3]]
    target = pauli_product_pow(operators, [1, 0, 1, 1])
    target_indices = _find_product_indices(operators, target)
    found = pauli_product(operators[target_indices])
    @test found == target
    # identity target
    @test _find_product_indices(operators, [0, 0, 0, 0, 0]) == []
end

@testset "find_pure_error/find_syndrome" begin
    code = steane_code()
    error = [0, 1, 3, 0, 0, 2, 0]
    syndrome = find_syndrome(code, error)
    pure_error = find_pure_error(code, syndrome)
    @test find_syndrome(code, pure_error) == syndrome

    #identity error
    identity = zeros(Int, 7)
    syndrome = find_syndrome(code, identity)
    @test all(==(0), syndrome)
    @test find_pure_error(code, syndrome) == identity
end

@testset "find_pure_errors" begin
    # 5-qubit code stabilizers: XZZXI, IXZZX, XIXZZ, ZXIXZ
    stabilizers = [[1, 3, 3, 1, 0], [0, 1, 3, 3, 1], [1, 0, 1, 3, 3], [3, 1, 0, 1, 3]]
    stabilizers_copy = deepcopy(stabilizers)
    pure_errors = find_pure_errors(stabilizers)
    @test stabilizers == stabilizers_copy  # stabilizers not modified
    # test commutation relations
    @test length(pure_errors) == length(stabilizers)
    @test [pauli_commutation(s, p) for s in stabilizers, p in pure_errors] == I
end

@testset "num_qubits" begin
    @test num_qubits(five_qubit_code()) == 5
    @test num_qubits(steane_code()) == 7
    @test num_qubits(random_code(4, 1)) == 4
    @test num_qubits(random_stabilizer_state(6)) == 6
end

@testset "verify_code" begin
    valid_code = random_code(6, 2)
    @test verify_code(valid_code)

    code_missing_pure_error = deepcopy(valid_code)
    pop!(code_missing_pure_error.pure_errors)
    @test !verify_code(code_missing_pure_error)

    code_missing_logical = deepcopy(valid_code)
    pop!(code_missing_logical.logicals)
    @test !verify_code(code_missing_logical)

    code_dependent_stabilizers = deepcopy(valid_code)
    pop!(code_dependent_stabilizers.stabilizers)
    push!(code_dependent_stabilizers.stabilizers, valid_code.stabilizers[1])
    @test !verify_code(code_dependent_stabilizers)

    code_noncommuting_stabilizers = deepcopy(valid_code)
    code_noncommuting_stabilizers.stabilizers[2] = valid_code.pure_errors[1]
    @test !verify_code(code_noncommuting_stabilizers)

    code_wrongorder_pure_errors = deepcopy(valid_code)
    pure_errors = code_wrongorder_pure_errors.pure_errors
    pure_errors[1], pure_errors[2] = pure_errors[2], pure_errors[1]
    @test !verify_code(code_wrongorder_pure_errors)

    code_invalid_pure_errors = deepcopy(valid_code)
    pure_errors = code_invalid_pure_errors.pure_errors
    pure_errors[1] = pauli_product.(pure_errors[1], pure_errors[2])
    @test !verify_code(code_invalid_pure_errors)

    code_noncommuting_logicals = deepcopy(valid_code)
    code_noncommuting_logicals.logicals[1] = valid_code.pure_errors[1]
    @test !verify_code(code_noncommuting_logicals)

    # test logging
    log_pattern = (:warn, "number of stabilizers and pure errors don't match!")
    @test_logs log_pattern verify_code(code_missing_pure_error; log_warn=true)
    @test_logs verify_code(code_missing_pure_error, log_warn=false)
end

@testset "gauge_code" begin
    new_code = five_qubit_surface_code()
    new_code = gauge_code(new_code,[[0,1]],[1])
    @test verify_code(new_code)
end
