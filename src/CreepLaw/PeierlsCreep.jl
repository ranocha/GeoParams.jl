export DislocationCreep,
    DislocationCreep_info,
    SetDislocationCreep,
    remove_tensor_correction,
    dεII_dτII,
    dτII_dεII

# Peierls Creep ------------------------------------------------
"""
    PeierlsCreep(n = 1.0NoUnits, r = 0.0NoUnits, A = 1.5MPa/s, E = 476.0kJ/mol, V = 6e-6m^3/mol, apparatus = AxialCompression )
    
Defines the flow law parameter of a peierls creep law.

The peierls creep law, as used by experimentalists, is given by  
```math  
     \\dot{\\gamma} = A \\sigma_\\mathrm{d}^2 \\exp\\left(-\\frac{E}{RT} \\left(1-\\sqrt{\\frac{\\sigma_\\mathrm{d}}{\\sigma_\\mathrm{p}}}}\\right)\\right)
```
where 
- ``n`` is the power law exponent  
- ``r`` is the exponent of fugacity dependence 
- ``A`` is a pre-exponential factor ``[\\mathrm{MPa}^{-n}s^{-1}]`` (if manually defined, ``n`` must be either pre-defined or substituted) 
- ``E`` is the activation energy ``\\mathrm{[kJ/mol]}`` 
- ``V`` is the activation volume ``\\mathrm{[m^3/mol]}`` 
- ``\\dot{\\gamma}`` is the strain rate ``\\mathrm{[1/s]}`` 
- ``\\sigma_\\mathrm{p}`` is the peierls stress ``\\mathrm{[MPa]}``
- ``\\sigma_\\mathrm{d}`` is the differential stress ``\\mathrm{[MPa]}`` which are converted into second invariants using the `Apparatus` variable that can be
either `AxialCompression`, `SimpleShear` or `Invariant`. If the flow law paramters are already given as a function of second invariants, choose `Apparatus=Invariant`.

# Example
```julia-repl 
julia> x2 = PeierlsCreep(n=1)
PeierlsCreep: n=1, A=1.5 MPa^-3 s^-1, E=476.0 kJ mol^-1, Apparatus=AxialCompression
```
"""
struct DislocationCreep{T,N,U1,U2,U3,U4} <: AbstractCreepLaw{T}
    Name::NTuple{N,Char}
    n::GeoUnit{T,U1} # power-law exponent
    A::GeoUnit{T,U2} # material specific rheological parameter
    E::GeoUnit{T,U3} # activation energy
    R::GeoUnit{T,U4} # universal gas constant
    Apparatus::Int8 # type of experimental apparatus, either AxialCompression, SimpleShear or Invariant
    FT::T # type of experimental apparatus, either AxialCompression, SimpleShear or Invariant
    FE::T # type of experimental apparatus, either AxialCompression, SimpleShear or Invariant

    function PeierlsCreep(;
        Name="",
        n=1.0NoUnits,
        A=1.5MPa^(-n) / s,
        E=476.0kJ / mol,
        R=8.3145J / mol / K,
        Apparatus=AxialCompression,
    )

        # Rheology name
        Name = String(join(Name))
        N = length(Name)
        NameU = NTuple{N,Char}(collect.(Name))
        
        # Corrections from lab experiments
        FT, FE = CorrectionFactor(Apparatus)
        # Convert to GeoUnits
        nU = n isa GeoUnit ? n : convert(GeoUnit, n)
        AU = A isa GeoUnit ? A : convert(GeoUnit, A)
        EU = E isa GeoUnit ? E : convert(GeoUnit, E)
        RU = R isa GeoUnit ? R : convert(GeoUnit, R)
        # Extract struct types
        T = typeof(nU).types[1]
        U1 = typeof(nU).types[2]
        U2 = typeof(AU).types[2]
        U3 = typeof(EU).types[2]
        U4 = typeof(RU).types[2]
        # Create struct
        return new{T,N,U1,U2,U3,U4}(
            NameU, nU, AU, EU, RU, Int8(Apparatus), FT, FE
        )
    end

    function PeierlsCreep(Name, n, A, E, R, Apparatus, FT, FE)
        return PeierlsCreep(;
            Name=Name, n=n, A=A, E=E, R=R, Apparatus=Apparatus
        )
    end
end

"""
    Transforms units from MPa, kJ etc. to basic units such as Pa, J etc.
"""

function Transform_PeierlsCreep(name; kwargs)
    p_in = PeierlsCreep_info[name][1]

    # Take optional arguments 
    v_kwargs = values(kwargs)
    val = GeoUnit.(values(v_kwargs))
    
    args = (Name=p_in.Name, n=p_in.n, A=p_in.A, E=p_in.E, Apparatus=p_in.Apparatus)
    p = merge(args, NamedTuple{keys(v_kwargs)}(val))
    
    Name = String(collect(p.Name))
    n = Value(p.n)
    A_Pa = uconvert(Pa^(-NumValue(p.n)) / s, Value(p.A))
    E_J = uconvert(J / mol, Value(p.E))

    Apparatus = p.Apparatus

    # args from database
    args = (Name=Name, n=n, A=A_Pa, E=E_J, Apparatus=Apparatus)
    
    return PeierlsCreep(; args...)
end

"""
    s = remove_tensor_correction(s::PeierlsCreep)

Removes the tensor correction of the creeplaw, which is useful to compare the implemented creeplaws
with the curves of the original publications, as those publications usually do not transfer their data to tensor format
"""
function remove_tensor_correction(s::PeierlsCreep)
    name = String(collect(s.Name))

    return PeierlsCreep(;
        Name=name, n=s.n, A=s.A, E=s.E, Apparatus=Invariant
    )
end

function param_info(s::PeierlsCreep)
    name = String(collect(s.Name))
    eq = L"\tau_{ij} = 2 \eta  \dot{\varepsilon}_{ij}"
    if name == ""
        return MaterialParamsInfo(; Equation=eq)
    end
    inf = PeierlsCreep_info[name][2]
    return MaterialParamsInfo(;
        Equation=eq, Comment=inf.Comment, BibTex_Reference=inf.BibTex_Reference
    )
end

#---------------------- All calculating equations are still wrong!!!! ---------------------------------#

# Calculation routines for linear viscous rheologies
# All inputs must be non-dimensionalized (or converted to consitent units) GeoUnits
@inline function compute_εII(
    a::PeierlsCreep, TauII::_T; T=one(precision(a)), args...
) where {_T}
    @unpack_val n, A, E, R = a
    FT, FE = a.FT, a.FE

    ε = A * fastpow(TauII * FT, n) * exp(-(E / (R * T))) / FE
    return ε
end

@inline function compute_εII(
    a::PeierlsCreep, TauII::Quantity; T=1K, args...
)
    @unpack_units n, A, E, R = a
    FT, FE = a.FT, a.FE

    ε = A * (TauII * FT)^n * exp(-(E / (R * T))) / FE

    return ε
end

function compute_εII!(
    EpsII::AbstractArray{_T,N},
    a::PeierlsCreep,
    TauII::AbstractArray{_T,N};
    T=ones(size(TauII))::AbstractArray{_T,N},
    kwargs...,
) where {N,_T}
    @inbounds for i in eachindex(EpsII)
        EpsII[i] = compute_εII(a, TauII[i]; T=T[i])
    end

    return nothing
end

@inline function dεII_dτII(
    a::PeierlsCreep, TauII::_T; T=one(precision(a)), args...
) where {_T}
    @unpack_val n, A, E, R = a
    FT, FE = a.FT, a.FE

    return fastpow(FT * TauII, -1 + n) *
           A *
           FT *
           n *
           exp(-(E / (R * T))) *
           (1 / FE)
end

@inline function dεII_dτII(
    a::PeierlsCreep, TauII::Quantity; T=1K, args...
)
    @unpack_units n, A, E, R = a
    FT, FE = a.FT, a.FE

    return (FT * TauII)^(-1 + n) *
           A *
           FT *
           n *
           exp(-(E / (R * T))) *
           (1 / FE)
end


"""
    compute_τII(a::PeierlsCreep, EpsII; P, T, f, args...)

Computes the stress for a peierls creep law given a certain strain rate

"""
@inline function compute_τII(
    a::PeierlsCreep, EpsII::_T; T=one(precision(a)), args...
) where {_T}
    local n, A, E, R
    if EpsII isa Quantity
        @unpack_units n, A, E, R = a
    else
        @unpack_val n, A, E, R = a
    end

    FT, FE = a.FT, a.FE

    return fastpow(A, -1 / n) *
           fastpow(EpsII * FE, 1 / n) *
           exp((E / (n * R * T))) / FT
end

@inline function compute_τII(
    a::PeierlsCreep, EpsII::Quantity; T=1K, args...
)
    @unpack_units n, A, E, R = a
    FT, FE = a.FT, a.FE

    τ = A^(-1 / n) * (EpsII * FE)^(1 / n) * exp((E / (n * R * T))) / FT

    return τ
end

"""
    compute_τII!(TauII::AbstractArray{_T,N}, a::PeierlsCreep, EpsII::AbstractArray{_T,N}; 
        T = ones(size(TauII))::AbstractArray{_T,N}, 

Computes the deviatoric stress invariant for a peierls creep law
"""
function compute_τII!(
    TauII::AbstractArray{_T,N},
    a::PeierlsCreep,
    EpsII::AbstractArray{_T,N};
    T=ones(size(TauII))::AbstractArray{_T,N},
    P=zero(TauII)::AbstractArray{_T,N},
    f=ones(size(TauII))::AbstractArray{_T,N},
    kwargs...,
) where {N,_T}
    @inbounds for i in eachindex(TauII)
        TauII[i] = compute_τII(a, EpsII[i]; T=T[i])
    end

    return nothing
end

@inline function dτII_dεII(
    a::PeierlsCreep, EpsII::_T; T=one(precision(a)), args...
) where {_T}
    @unpack_val n, A, E, R = a
    FT, FE = a.FT, a.FE

    return (
        FE *
        (A^(-1 / n)) *
        ((EpsII * FE)^(1 / n - 1)) *
        exp((E / (R * T * n)))
    ) / (FT * n)
end

@inline function dτII_dεII(
    a::PeierlsCreep, EpsII::Quantity; T=1K, args...
)
    @unpack_units n, A, E, R = a
    FT, FE = a.FT, a.FE

    return (
        FE *
        (A^(-1 / n)) *
        ((EpsII * FE)^(1 / n - 1)) *
        exp((E / (R * T * n)))
    ) / (FT * n)
end

# Print info 
function show(io::IO, g::PeierlsCreep)
    return print(
        io,
        "PeierlsCreep: Name = $(String(collect(g.Name))), n=$(Value(g.n)), A=$(Value(g.A)), E=$(Value(g.E)), FT=$(g.FT), FE=$(g.FE), Apparatus=$(g.Apparatus)",
    )
end
#-------------------------------------------------------------------------

# load collection of peierls creep laws
include("Data/PeierlsCreep.jl")
