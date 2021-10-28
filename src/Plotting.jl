"""
    This provides a few plotting routines, for example, for CreepLaws
"""

using LaTeXStrings
using Unitful
using Parameters
using ..Units
using ..MaterialParameters
using ..MeltingParam
using .Plots

using GeoParams: AbstractMaterialParam, AbstractMaterialParamsStruct
using .MaterialParameters.CreepLaw: CreepLawVariables, ComputeCreepLaw_TauII, AbstractCreepLaw
using .MaterialParameters.HeatCapacity: AbstractHeatCapacity, ComputeHeatCapacity
using .MaterialParameters.Conductivity: AbstractConductivity, ComputeConductivity
using .MeltingParam: AbstractMeltingParam, ComputeMeltingParam

export 
    PlotStressStrainrate_CreepLaw,
    PlotHeatCapacity,
    PlotConductivity,
    PlotMeltFraction 


"""
    PlotStressStrainrate_CreepLaw(x::AbstractCreepLaw; p::CreepLawParams=nothing, Strainrate=(1e-18,1e-12), CreatePlot::Bool=false)

Plots deviatoric stress versus deviatoric strain rate for a single creeplaw. 
    Note: if you want to create plots or use the `CreatePlot=true` option you need to install the `Plots.jl` package in julia
    which is not added as a dependency here (as it is a rather large dependency).

# Example 1    
```julia-repl
julia> x=LinearViscous()
Linear viscosity: η=1.0e20 Pa s
julia> Tau_II, Eps_II,  = PlotStressStrainrate_CreepLaw(x);
```
Next you can plot this with
```julia-repl
julia> using Plots;
julia> plot(ustrip(Eps_II),ustrip(Tau_II), xaxis=:log, yaxis=:log,xlabel="strain rate [1/s]",ylabel="Dev. Stress [MPa]")
```
Note that `ustrip` removes the units of the arrays, as many of the plotting packages don't know how to deal with that.

You could also have done:
```julia-repl
julia> using Plots;
julia> Tau_II, Eps_II, pl = PlotStressStrainrate_CreepLaw(x,CreatePlot=true);
```
which will generate the following plot
![subet1](./assets/img/Stress_Strainrate_LinearViscous.png)

The plot can be customized as 
```julia-repl
julia> plot(pl, title="Linear viscosity", linecolor=:red)
```
See the [Plots.jl](https://github.com/JuliaPlots/Plots.jl) package for more options.

"""
function PlotStressStrainrate_CreepLaw(x::AbstractCreepLaw; p=nothing, Strainrate=(1e-18/s,1e-12/s), CreatePlot::Bool=false)

    if isnothing(p); p = CreepLawParams();  end

    if isDimensional(x)==false
       error("The struct with Creep Law parameters: $(typeof(x)) should be in dimensional units for plotting. You can use Dimensionalize! to do that.")
    end

    # Define strainrate 
    Eps_II = range(ustrip(Strainrate[1])/s, stop=ustrip(Strainrate[2])/s, length=101)/s
    Tau_II = ComputeCreepLaw_TauII(Eps_II, x, p)                  # deviatoric stress

    # Transfer to GeoUnits
    Eps_II = GeoUnit(Eps_II);
    Tau_II = GeoUnit(Tau_II/1e6);

    if CreatePlot
        try 
            pl = plot(ustrip(Eps_II), ustrip(Tau_II), 
                xaxis=:log, xlabel=L"\textrm{deviatoric strain rate  } \dot{\varepsilon}_{II} \textrm{    [1/s]}", 
                yaxis=:log, ylabel=L"\textrm{deviatoric stress  }\tau_{II} \textrm{    [MPa]}",
                legend=false,show = true)
        catch
            error("It seems that you did not install, or did not load Plots.jl. For plotting, please add that with `add Plots` in the package manager and type `using Plots` before running this.")
        end

        return Tau_II, Eps_II, pl
    else
        return Tau_II, Eps_II
    end

    
end


"""
    T,Cp,plt = PlotHeatCapacity(cp::AbstractHeatCapacity; T=nothing, plt=nothing, lbl=nothing)

Creates a plot of temperature `T` vs. heat capacity, as specified in cp (which can be temperature-dependent).

# Optional parameters
- T: temperature range
- plt: a previously generated plotting object
- lbl: label of the curve

# Example
```
julia> cp = T_HeatCapacity_Whittacker()
julia> T,Cp,plt = PlotHeatCapacity(cp)
```
you can now save the figure to disk with:
```
julia> using Plots
julia> savefig(plt,"Tdependent_heatcapacity.png")
```

"""
function PlotHeatCapacity(cp::AbstractHeatCapacity; T=nothing, plt=nothing, lbl=nothing)

    if isnothing(T)
        T = (273:10:1250)*K
    end

    Cp       =   ComputeHeatCapacity(T,cp)
    if length(Cp) == 1
        Cp = ones(size(T))*Cp
    end

    if isnothing(plt)
        plt = plot(ustrip(T), ustrip(Cp), label=lbl)
    else
        plt = plot!(ustrip(T), ustrip(Cp), label=lbl)
    end   
    plot!(plt,   xlabel="Temperature [$(unit(T[1]))]",
                 ylabel="Cp [$(unit(Cp[1]))]")
    gui(plt)

    return T,Cp, plt
end


"""
    T,Kk,plt = PlotConductivity(cp::AbstractConductivity; T=nothing, plt=nothing, lbl=nothing)

Creates a plot of temperature `T` vs. thermal conductivity, as specified in `k` (which can be temperature-dependent).

# Optional parameters
- `T`: temperature range
- `plt`: a previously generated plotting object
- `lbl`: label of the curve

# Example
```
julia> k = T_Conductivity_Whittacker()
julia> T,KK,plt = PlotConductivity(k)
```
you can now save the figure to disk with:
```
julia> using Plots
julia> savefig(plt,"Tdependent_conductivity.png")
```

"""
function PlotConductivity(k::AbstractConductivity; T=nothing, P=nothing, plt=nothing, lbl=nothing)

    if isnothing(T)
        T = (273:10:1250)*K
    end
    if isnothing(P)
        P = 1e6Pa*ones(size(T))
    end

    Cond       =   ComputeConductivity(P,T,k)
    if length(Cond) == 1
        Cond = ones(size(T))*Cond
    end

    if isnothing(plt)
        plt = plot(ustrip(T), ustrip(Cond), label=lbl)
    else
        plt = plot!(ustrip(T), ustrip(Cond), label=lbl)
    end   
    plot!(plt,   xlabel="Temperature [$(unit(T[1]))]",
                 ylabel="Thermal conductivity [$(unit(Cond[1]))]")
    gui(plt)

    return T,Cond, plt
end

"""
    T,phi,plt = PlotMeltFraction(p::AbstractMeltingParam; T=nothing, plt=nothing, lbl=nothing)

Creates a plot of temperature `T` vs. melt fraction, as specified in `p`. 
The 1D curve can be evaluated at a specific pressure `P` which can be given as a scalar or as an array of the same size as `T`

# Optional parameters
- `T`: temperature range
- `P`: pressure 
- `plt`: a previously generated plotting object
- `lbl`: label of the curve

# Example
```
julia> p        =  MeltingParam_Caricchi()
julia> T,phi,plt = PlotMeltFraction(p)
```
you can now save the figure to disk with:
```
julia> using Plots
julia> savefig(plt,"MeltFraction.png")
```

"""
function PlotMeltFraction(p::AbstractMeltingParam; T=nothing, P=nothing, plt=nothing, lbl=nothing)
    Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
    
    if isnothing(T)
        T = (500:10:1500)*K
    end
    T_C = ustrip(T) .- 273.15

    if isnothing(P) 
        P = 1e6Pa*ones(size(T))
    end
    if length(P) == 1
        P = P*ones(size(T))
    end

    phi       =   ComputeMeltingParam(P,T,p)
    if length(phi) == 1
        phi = ones(size(T))*phi
    end

    if isnothing(plt)
       plt = plot(T_C, ustrip(phi), label=lbl)
    else
       plt = plot!(T_C, ustrip(phi), label=lbl)
    end   
    plot!(plt,   xlabel="Temperature [C]",
                 ylabel="Melt Fraction \\Phi")
    gui(plt)

    return T,phi, plt
end



