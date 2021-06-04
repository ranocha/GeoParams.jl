module CreepLaw

# This implements viscous creep laws and routines to compute with them
#
# Note that various simple creep laws are defined in this file; 
# more complex ones (such as DislocationCreep) are in separate files 
# in the same directory
#
# In case you want to add new creep laws, have a look at how the ones
# here are implemented. Please add tests as well!

using Parameters, LaTeXStrings, Unitful
using ..Units
using GeoParams: AbstractMaterialParam
import Base.show

abstract type AbstractCreepLaw <: AbstractMaterialParam end

export  CreepLaw_EpsII, CreepLaw_TauII,         # calculation routines
        LinearViscous, 
        PowerlawViscous

# Linear viscous rheology ------------------------------------------------
"""
    LinearViscous(η=1e20Pa*s)
    
Defines a linear viscous creeplaw 

The (isotopic) linear viscous rheology is given by  
```math  
    \\dot{\\varepsilon}_{ij}  = {\\tau_{ij}  \\over 2 \\eta }
```
where ``\\eta`` is the effective viscosity [Pa*s].
"""
@with_kw_noshow mutable struct LinearViscous <: AbstractCreepLaw
    equation::LaTeXString   =   L"\tau_{ij} = 2 \eta  \dot{\varepsilon}_{ij}"     
    η::GeoUnit            =   1e20Pa*s                # viscosity
end

# Calculation routines for linear viscous rheologies
function CreepLaw_EpsII(TauII, s::LinearViscous)
    @unpack η   = s
    
    return EpsII = TauII/(2.0*η);
end

function CreepLaw_TauII(EpsII, s::LinearViscous)
    @unpack η   = s
    
    return TauII = 2.0*η*EpsII;
end

# Print info 
function show(io::IO, g::LinearViscous)  
    print(io, "Linear viscosity: η=$(g.η.val)")  
end
#-------------------------------------------------------------------------

# Powerlaw viscous rheology ----------------------------------------------
"""
    PowerlawViscous(eta=1e20Pa*s, )
    
Defines a simple power law viscous creeplaw 

The (isotopic) linear viscous rheology is given by  
```math  
    {\\tau_{ij}  = \\η_0 ( \\varepsilon_{II} \\over \\varepsilon_{II} ) 
```
where ``\\eta`` is the effective viscosity [Pa*s].
"""
@with_kw_noshow mutable struct PowerlawViscous <: AbstractCreepLaw
    η0::GeoUnit     =  1e18Pa*s            # reference viscosity 
    n::GeoUnit      =  2.0*NoUnits         # powerlaw exponent
    ε0::GeoUnit     =  1e-15*1/s;          # reference strainrate
end

# Print info 
function show(io::IO, g::PowerlawViscous)  
    print(io, "Powerlaw viscosity: η0=$(g.η0.val), n=$(g.n.val), ε0=$(g.ε0.val) ")
end
#-------------------------------------------------------------------------



# Help info for the calculation routines
"""
    CreepLaw_EpsII(TauII, s:<AbstractCreepLaw)

Returns the strainrate invariant ``\\dot{\\varepsilon}_{II}`` for a given deviatoric stress 
invariant ``\\tau_{II}`` for any of the viscous creep laws implemented.


```math  
    \\varepsilon_{II}   = f( \\tau_{II} ) 
```

"""
CreepLaw_EpsII

"""
    CreepLaw_TauII(EpsII, s:<AbstractCreepLaw)

Returns the deviatoric stress invariant ``\\tau_{II}`` for a given strain rate  
invariant ``\\dot{\\varepsilon}_{II}`` for any of the viscous creep laws implemented.

```math  
    \\tau_{II}  = f( \\varepsilon_{II} ) 
```

"""
CreepLaw_TauII


end