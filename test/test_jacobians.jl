using StaticArrays, GeoParams, ForwardDiff

# Define a range of rheological components
v1 = SetDiffusionCreep("Dry Anorthite | Rybacki et al. (2006)")
v2 = SetDislocationCreep("Dry Anorthite | Rybacki et al. (2006)")
v3 = LinearViscous()
v4 = LinearViscous(η=1e22Pa*s)
e1 = ConstantElasticity()           # elasticity
e2 = SetConstantElasticity(; G=5e10, Kb=1e11)
#pl1= DruckerPrager(C=1e6)                # plasticity
pl1= DruckerPrager(C=1e6/cosd(30))        # plasticity which ends up with the same yield stress as pl3
pl2= DruckerPrager(C=1e6, ϕ=0, Ψ=10)      # plasticity
pl3= DruckerPrager(C=1e6, ϕ=0)            # plasticity
    
# Parallel elements
p1 = Parallel(v3,v4)                # linear elements
p2 = Parallel(v1,v2)                # includes nonlinear viscous elements
p3 = Parallel(v1,v2,v3)             # includes nonlinear viscous elements
p4 = Parallel(pl1, LinearViscous(η=1e20Pa*s)) # viscoplastic regularisation
# CompositeRheologies
c1 = CompositeRheology(v1,v2)
c2 = CompositeRheology(v3,v4)       # two linear rheologies
c3 = CompositeRheology(v1,v2, e1)   # with elasticity
c4 = CompositeRheology(v1,v3, p1)   # with linear || element
c5 = CompositeRheology(v1,v4, p2)   # with nonlinear || element
c6 = CompositeRheology(v1,v4,p1,p2) # with 2 || elements
c7 = CompositeRheology(v4,e1)       # viscoelastic with linear viscosity
c8 = CompositeRheology(v4,e1,pl1)   # with plastic element
c9 = CompositeRheology(v4,e1,p4)    # with visco-plastic parallel element
c10= CompositeRheology(e1,pl3)      # elastoplastic
c11= CompositeRheology(e1,Parallel(pl3,LinearViscous(η=1e19Pa*s)))      # elasto-viscoplastic

c12= CompositeRheology(e2,v3)       # viscoelasticity with volumetric elasticity
c13= CompositeRheology(e2,pl2)      # volumetric elastoplastic

c14= CompositeRheology(SetConstantElasticity(G=1e10, Kb=2e11), LinearViscous(η=1e20), DruckerPrager(C=3e5, Ψ=10))   # case A
c15= CompositeRheology(SetConstantElasticity(G=1e10, Kb=2e11), LinearViscous(η=1e20), Parallel(DruckerPrager(C=3e5, Ψ=10),LinearViscous(η=1e19Pa*s)))   # case A
c16= CompositeRheology(SetConstantElasticity(G=1e10, Kb=2e11), LinearViscous(η=1e20), DruckerPrager_regularised(C=3e5, Ψ=10, η_vp=1e19))   # case A
p4 = Parallel(c3,v3)                # Parallel element with composite one as well    

# Check that we can construct complicated rheological elements
c = CompositeRheology( (v1, v2, v3, e1, Parallel(p1, v1, v2),v2, Parallel(p1, v1), v2,v3 ))   
c = CompositeRheology( (v1, v2, v3, e1, Parallel(p1, e1, Parallel( CompositeRheology(v1, v2), v3) ), v2,v3) )   
c = Parallel(CompositeRheology(v2,v3,e1, Parallel(v2,v3),v2, Parallel(v2,CompositeRheology(v3, v2))),v3,CompositeRheology(e1,p1))
    
args = (T=900.0, d=100e-6, τII_old=1e6, dt=1e8)
εII, τII = 2e-15, 2e6
# compute_τII(v, εII, args, verbose=false);

c = CompositeRheology(e1,v4)       # two linear rheologies
εij, τij, τij_old  = ntuple(x -> rand(3), 3) 
args = merge(args, (;τij_old=τij_old) )
compute_ε(e1, τij, args)
compute_τ(e1, εij, args)
compute_dτdε(e1, εij, args)
compute_dεdτ(e1, εij, args)

compute_ε(v4, τij, args)
compute_τ(v4, εij, args)
compute_dτdε(v4, εij, args)
compute_dεdτ(v4, εij, args)

εij, τij, τij_old  = ntuple(x ->Tuple(rand(3)), 3) 
compute_ε(e1, τij, args)
compute_τ(e1, εij, args)
compute_dτdε(e1, εij, args)
compute_dεdτ(e1, εij, args)

compute_ε(v4, τij, args)
compute_τ(v4, εij, args)
compute_dτdε(v4, εij, args)
compute_dεdτ(v4, εij, args)

εij, τij, τij_old  = ntuple(x -> SVector{3,Float64}(rand(3)), 3) 
compute_ε(e1, τij, args)
compute_τ(e1, εij, args)
compute_dτdε(e1, εij, args)
compute_dεdτ(e1, εij, args)

compute_ε(v4, τij, args)
compute_τ(v4, εij, args)
compute_dτdε(v4, εij, args)
compute_dεdτ(v4, εij, args)

v = CompositeRheology(e1, v4)

import GeoParams: compute_dτdε
@generated function compute_dτdε(v::CompositeRheology{T1, N1}, εij::SVector{N2, T2}, args) where {N1, T1, N2, T2}
    quote
        τij = @SVector zeros($N2)
        ∂τijετij = @SMatrix zeros($N2, $N2)
        Base.@nexprs $N1 i -> (
            V = compute_dτdε(v.elements[i], εij, args);
            τij = τij .+ V[1];
            ∂τijετij = ∂τijετij .+ V[2];
        )
        return τij, ∂τijετij
    end
end

@btime compute_dτdε($v, $εij, $args)

@btime compute_τij($v, $(Tuple(εij)), $args, $(Tuple(args.τij_old)))

pl = DruckerPrager_regularised()

function compute_τ(v::DruckerPrager_regularised, εij; η=1.0, dt=1.0, kwargs...)
    τij    = @. 2 * η * εij
    τII    = second_invariant(τij) # don't worry, same as: τii = sqrt(0.5*(τip[1]^2 + τip[2]^2) + τip[3]^2)
    τy     = v.C * v.cosϕ # + τ[4]*pl.sinϕ             # need to add cosϕ to call it Drucker-Prager but this one follows Stokes2D_simpleVEP
    F      = τII - τy  
    if F>0.0 
        λ   = F/(η + v.ηvp + K * dt * v.sinϕ * v.sinψ)
        τij = @. 2 * η *(εij -0.5 * λ * τij /τII)
    end
    τij
end

@btime compute_τ($pl, $x; $(args)...)
compute_τ(pl, x; args...)

args = merge(args, (; η=1,))

jacobian(x -> compute_dτdε(pl, x; args...), εij)


function fooII(v::AbstractPlasticity, τij, args; tol=1e-6)
    τII   = second_invariant(τij)
    η_np  = (τII - args.τII_old)/(2.0*args.ε_np)
    F     = compute_yieldfunction(v, merge(args, (τII=τII,)))

    λ    = 0.0 


    iter = 0
    λ    = 0.0 
    ϵ    = 2.0 * tol
    τII_pl = τII
    while (ϵ > tol) && (iter<100)
        #   τII_pl = τII -  2*η_np*λ*∂Q∂τII
        #   F(τII_pl)
        #   dF/dλ = (dF/dτII)*(dτII/dλ) = (dF/dτII)*(2*η_np*∂Q∂τII)
        
        iter  += 1
        τII_pl = τII - 2 * η_np * λ * ∂Q∂τII(v, τII_pl, args)       # update stress
        F      = compute_yieldfunction(v, merge(args, (τII=τII_pl,)))
        dFdλ   = ∂F∂τII(v, τII, args)*(2*η_np*∂Q∂τII(v, τII, args))
        λ     -= -F / dFdλ
        ϵ      = F
        # @print(verbose, "    plastic iter $(iter) ϵ=$ϵ λ=$λ, F=$F")
    end

    ε_pl = λ*∂Q∂τII(v, τII, args) * τij / τII

    # ε_pl = λ*∂Q∂τII(v, τII_pl, args)
    
    # return ε_pl
end

jacobian(x -> fooII(pl, x, args), τij)
fooII(pl, τij, args)

args = merge(args, (;ε_np=2.0, ))