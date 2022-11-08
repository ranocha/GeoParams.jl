using Test
using GeoParams

@testset "StressComputations" begin

    # use a (linear) viscoelastic setup
    η, G = 10.0, 1.0
    t_M = η / G
    εxx, εyy, εxy = 1.0, -1.1, 2.3 # predefined strainrates 
    ε = (εxx, εyy, εxy)
    args = (;)
    c_lin = CompositeRheology(LinearViscous(; η=η), ConstantElasticity(; G=G)) # linear VE

    t = LinRange(0, 4 * t_M, 100)
    dt = t[2] - t[1]

    # Analytical solution
    τxx = @. 2.0 * η * (1.0 - exp(-t / t_M)) * εxx
    τyy = @. 2.0 * η * (1.0 - exp(-t / t_M)) * εyy
    τxy = @. 2.0 * η * (1.0 - exp(-t / t_M)) * εxy
    τii = sqrt.(0.5 * (τxx .^ 2 .+ τyy .^ 2) .+ τxy .^ 2)
    εII = sqrt.(0.5 * (εxx .^ 2 .+ εyy .^ 2) .+ εxy .^ 2)

    # Manual integration
    τxx_n = zeros(size(τxx))
    τyy_n = zeros(size(τyy))
    τxy_n = zeros(size(τxy))
    τII_n = zeros(size(τxy))
    for i in 2:length(τxx_n)
        η_e = dt * G
        η_ve = inv(1.0 / η_e + 1.0 / η)
        τxx_n[i] = 2 * η_ve * (εxx + 0.5 * τxx_n[i - 1] / η_e)
        τyy_n[i] = 2 * η_ve * (εyy + 0.5 * τyy_n[i - 1] / η_e)
        τxy_n[i] = 2 * η_ve * (εxy + 0.5 * τxy_n[i - 1] / η_e)
        τII_n[i] = second_invariant((τxx_n[i], τyy_n[i], τxy_n[i]))
    end

    # 0D solution assuming this to be a scalar (wrong!)
    t_vec, τ0D_vec = time_τII_0D(c_lin, εII, args; t=(0.0, t_M * 4), nt=100, verbose=false)

    # 0D solution with tensor input:
    t_vec, τij_vec, τII_vec = time_τII_0D(
        c_lin, ε, args; t=(0.0, t_M * 4), nt=100, verbose=false
    )

    # Time-dependent (correct) solution
    τxx_vec = zeros(size(τxx))
    τyy_vec = zeros(size(τyy))
    τxy_vec = zeros(size(τxy))
    τ_vec = zeros(size(τxx))
    for i in 2:length(τxx_vec)
        τ_o = (τxx_vec[i - 1], τyy_vec[i - 1], τxy_vec[i - 1])
        args = (dt=dt, τII_old=0.0)
        τij, τII = compute_τij(c_lin, ε, args, τ_o)
        τxx_vec[i] = τij[1]
        τyy_vec[i] = τij[2]
        τxy_vec[i] = τij[3]
        τ_vec[i] = τII
    end

    # check
    @test abs(sum(τxx_n .- τxx_vec)) < 1e-10
    @test abs(sum(τyy_n .- τyy_vec)) < 1e-10
    @test abs(sum(τxy_n .- τxy_vec)) < 1e-10
    @test abs(sum(τII_n .- τ_vec)) < 1e-10
    @test abs(sum(τII_n .- τII_vec)) < 1e-10

    # Time-dependent (correct) solution for multiple material phases
    MatParam = (
        SetMaterialParams(; Name="Matrix", Phase=1, CompositeRheology=c_lin),
        SetMaterialParams(; Name="Inclusion", Phase=2, CompositeRheology=c_lin),
    )
    for phase_i in 1:2
        for i in 2:length(τxx_vec)
            τ_o = (τxx_vec[i - 1], τyy_vec[i - 1], τxy_vec[i - 1])
            args = (dt=dt, τII_old=0.0)
            τij, τII = compute_τij(MatParam, ε, args, τ_o, phase_i)
            τxx_vec[i] = τij[1]
            τyy_vec[i] = τij[2]
            τxy_vec[i] = τij[3]
            τ_vec[i] = τII
        end

        # check
        @test abs(sum(τxx_n .- τxx_vec)) < 1e-10
        @test abs(sum(τyy_n .- τyy_vec)) < 1e-10
        @test abs(sum(τxy_n .- τxy_vec)) < 1e-10
        @test abs(sum(τII_n .- τ_vec)) < 1e-10
        @test abs(sum(τII_n .- τII_vec)) < 1e-10
    end

    # Time-dependent (correct) solution for multiple material phases on a staggered grid
    phase_1 = (1, 1, (1,1,1,1))
    phase_2 = (2, 2, (2,2,2,2))
    phase_3 = (1, 1, (2,2,2,2))
    phase_4 = (2, 2, (1,1,1,1))
    ε_phase = (εxx, εyy, (εxy, εxy, εxy, εxy))
    for phase_i in (phase_1, phase_2, phase_3, phase_4)
        for i in 2:length(τxx_vec)
            τ_o = (τxx_vec[i - 1], τyy_vec[i - 1], (τxy_vec[i - 1], τxy_vec[i - 1], τxy_vec[i - 1], τxy_vec[i - 1]))
            args = (dt=dt, τII_old=0.0)
            τij, τII = compute_τij(MatParam, ε_phase, args, τ_o, phase_i)
            τxx_vec[i] = τij[1]
            τyy_vec[i] = τij[2]
            τxy_vec[i] = τij[3]
            τ_vec[i] = τII
        end

        # check
        @test abs(sum(τxx_n .- τxx_vec)) < 1e-10
        @test abs(sum(τyy_n .- τyy_vec)) < 1e-10
        @test abs(sum(τxy_n .- τxy_vec)) < 1e-10
        @test abs(sum(τII_n .- τ_vec)) < 1e-10
        @test abs(sum(τII_n .- τII_vec)) < 1e-10
    end
end