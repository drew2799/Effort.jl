#TODO: this part should be moved to a dedicate package. While necessary to a full Effort
#functionality, this could be factorized to a new module, specifically taylored to this goal
# and maybe used in other packages, maybe in AbstractCosmologicalEmulators?

abstract type AbstractCosmology end


"""
    w0waCDMCosmology(ln10Aₛ::Number, nₛ::Number, h::Number, ωb::Number, ωc::Number, mν::Number=0., w0::Number=-1., wa::Number=0.)

This struct contains the value of the cosmological parameters for ``w_0 w_a``CDM cosmologies.

## Keyword arguments

 - `ln10Aₛ` and `nₛ`, the amplitude and the tilt of the primordial power spectrum fluctuations
 - `h`, the value of the reduced Hubble paramater
 - `ωb` and `ωc`, the physical energy densities of baryons and cold dark matter
 - `mν`, the sum of the neutrino masses in eV
 - `w₀` and `wₐ`, the Dark Energy equation of state parameters in the [CPL parameterization](https://arxiv.org/abs/astro-ph/0208512)
"""
@kwdef mutable struct w0waCDMCosmology <: AbstractCosmology
    ln10Aₛ::Number
    nₛ::Number
    h::Number
    ωb::Number
    ωc::Number
    mν::Number = 0.0
    w0::Number = -1.0
    wa::Number = 0.0
end

"""
    _F(y)

# Arguments
- `y`: The value of the parameter `y` for which the integral is calculated.

# Returns
The value of the definite integral for the given `y`.

# Details
The integrand is defined as:
``f(x, y) = x^2 \\cdot \\sqrt{x^2 + y^2} / (1 + e^x)``

The integration is performed over the domain `(0, Inf)` for the variable `x`.
A relative tolerance of `1e-12` is used for the integration solver.
"""
function _F(y)
    f(x, y) = x^2 * √(x^2 + y^2) / (1 + exp(x))
    domain = (zero(eltype(Inf)), Inf) # (lb, ub)
    prob = IntegralProblem(f, domain, y; reltol=1e-12)
    sol = solve(prob, QuadGKJL())[1]
    return sol
end

"""
    _get_y(mν, a; kB=8.617342e-5, Tν=0.71611 * 2.7255)

Calculates the dimensionless parameter `y` used in the integral function [`_F(y)`](@ref).

The parameter `y` is calculated based on the neutrino mass, scale factor,
Boltzmann constant, and neutrino temperature according to the formula:

`y = mν * a / (kB * Tν)`

# Arguments
- `mν`: Neutrino mass (in units where `kB` and `Tν` are defined).
- `a`: Scale factor.

# Keyword Arguments
- `kB`: Boltzmann constant (default: 8.617342e-5 eV/K).
- `Tν`: Neutrino temperature (default: 0.71611 * 2.7255 K).

# Returns
The calculated dimensionless parameter `y`.
"""
function _get_y(mν, a; kB=8.617342e-5, Tν=0.71611 * 2.7255)
    return mν * a / (kB * Tν)
end

"""
    _dFdy(y)

Calculates the definite integral of the function ``f(x, y) = x^2 / ((1 + e^x) \\cdot \\sqrt{x^2 + y^2})``
with respect to `x` from `0` to `Inf`, and then multiplies the result by `y`.

This function is the derivative of the integral function [`_F(y)`](@ref)
with respect to `y`.

# Arguments
- `y`: The value of the parameter `y` used in the integrand and as a multiplicative factor.

# Returns
The value of the definite integral multiplied by `y` for the given `y`.
"""
function _dFdy(y)
    f(x, y) = x^2 / ((1 + exp(x)) * √(x^2 + y^2))
    domain = (zero(eltype(Inf)), Inf) # (lb, ub)
    prob = IntegralProblem(f, domain, y; reltol=1e-12)
    sol = solve(prob, QuadGKJL())[1]
    return sol * y
end

"""
    _ΩνE2(a, Ωγ0, mν; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)

Calculates the energy density of relic neutrinos, scaled by the critical density,
at a given scale factor `a`, for a *single* neutrino mass.

This function accounts for the contribution of a single neutrino mass `mν` to the total
energy density. It uses [`_F(y)`](@ref) to incorporate the effect of neutrino mass and temperature.

# Arguments
- `a`: The scale factor.
- `Ωγ0`: The photon density parameter today.
- `mν`: The neutrino mass (a single value).

# Keyword Arguments
- `kB`: Boltzmann constant (default: 8.617342e-5 eV/K).
- `Tν`: Neutrino temperature (default: 0.71611 * 2.7255 K).
- `Neff`: Effective number of neutrino species (default: 3.044).

# Returns
The calculated neutrino energy density parameter `ΩνE2` at scale factor `a` for the given mass.

# Details
The calculation involves a factor `Γν` derived from `Neff` and the ratio of
neutrino to photon temperatures. The main term is proportional to `Ωγ0 / a^4`
multiplied by `F_interpolant(_get_y(mν, a))`.

The parameter `y` passed to `F_interpolant` is calculated using [`_get_y(mν, a)`](@ref).

# Formula
The formula used is:
`ΩνE2 = (15 / π^4) * Γν^4 * (Ωγ0 / a^4) * F(y)`
where `Γν = (4/11)^(1/3) * (Neff/3)^(1/4)` and `y = mν * a / (kB * Tν)`.

# See Also
- [`_get_y(mν, a)`](@ref): Calculates the `y` parameter.
- [`_F(y)`](@ref): The integral function used as `F_interpolant`.
- [`_ΩνE2(a, Ωγ0, mν::AbstractVector)`](@ref): Method for a vector of neutrino masses.
"""
function _ΩνE2(a, Ωγ0, mν; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)
    Γν = (4 / 11)^(1 / 3) * (Neff / 3)^(1 / 4)
    return 15 / π^4 * Γν^4 * Ωγ0 / a^4 * F_interpolant(_get_y(mν, a))
end

"""
    _ΩνE2(a, Ωγ0, mν::AbstractVector; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)

Calculates the energy density of relic neutrinos, scaled by the critical density,
at a given scale factor `a`, for a *vector* of neutrino masses.

This function accounts for the combined contribution of multiple neutrino masses
to the total energy density by summing the individual contributions. It uses the
`F_interpolant` function (which is equivalent to [`_F(y)`](@ref)) for each mass.

# Arguments
- `a`: The scale factor.
- `Ωγ0`: The photon density parameter today.
- `mν`: A vector of neutrino masses (`AbstractVector`).

# Keyword Arguments
- `kB`: Boltzmann constant (default: 8.617342e-5 eV/K).
- `Tν`: Neutrino temperature (default: 0.71611 * 2.7255 K).
- `Neff`: Effective number of neutrino species (default: 3.044).

# Returns
The calculated total neutrino energy density parameter `ΩνE2` at scale factor `a`
for the sum of contributions from all masses in the vector.

# Details
The calculation involves a factor `Γν` derived from `Neff` and the ratio of
neutrino to photon temperatures. The main term is proportional to `Ωγ0 / a^4`
multiplied by the sum of `F_interpolant(_get_y(mν_i, a))` for each mass `mν_i`
in the input vector `mν`.

The parameter `y` passed to `F_interpolant` for each mass is calculated using
[`_get_y(mν_i, a)`](@ref).

# Formula
The formula used is:
`ΩνE2 = (15 / π^4) * Γν^4 * (Ωγ0 / a^4) * Σ F(y_i)`
where `Γν = (4/11)^(1/3) * (Neff/3)^(1/4)` and `y_i = mν_i * a / (kB * Tν)`.

# See Also
- [`_get_y(mν, a)`](@ref): Calculates the `y` parameter for each mass.
- [`_F(y)`](@ref): The integral function used as `F_interpolant`.
- [`_ΩνE2(a, Ωγ0, mν)`](@ref): Method for a single neutrino mass.
"""
function _ΩνE2(a, Ωγ0, mν::AbstractVector; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)
    Γν = (4 / 11)^(1 / 3) * (Neff / 3)^(1 / 4)
    sum_interpolant = 0.0
    for mymν in mν
        sum_interpolant += F_interpolant(_get_y(mymν, a))
    end
    return 15 / π^4 * Γν^4 * Ωγ0 / a^4 * sum_interpolant
end

"""
    _dΩνE2da(a, Ωγ0, mν; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)

Calculates the derivative of the neutrino energy density parameter [`_ΩνE2`](@ref)
with respect to the scale factor `a`, for a *single* neutrino mass.

This function computes the derivative of the expression for `_ΩνE2` by applying
the chain rule, involving both [`_F(y)`](@ref)
and [`_dFdy(y)`](@ref) functions.

# Arguments
- `a`: The scale factor.
- `Ωγ0`: The photon density parameter today.
- `mν`: The neutrino mass (a single value).

# Keyword Arguments
- `kB`: Boltzmann constant (default: 8.617342e-5 eV/K).
- `Tν`: Neutrino temperature (default: 0.71611 * 2.7255 K).
- `Neff`: Effective number of neutrino species (default: 3.044).

# Returns
The calculated derivative `d(ΩνE2)/da` at scale factor `a` for the given mass.

# Details
The calculation is based on the derivative of the `_ΩνE2` formula with respect to `a`.

# See Also
- [`_ΩνE2(a, Ωγ0, mν)`](@ref): The function whose derivative is calculated.
- [`_get_y(mν, a)`](@ref): Calculates the `y` parameter.
- [`_F(y)`](@ref): The integral function used as `F_interpolant`.
- [`_dFdy(y)`](@ref): The function used as `dFdy_interpolant`.
- [`_dΩνE2da(a, Ωγ0, mν::AbstractVector)`](@ref): Method for a vector of neutrino masses.
"""
function _dΩνE2da(a, Ωγ0, mν; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)
    Γν = (4 / 11)^(1 / 3) * (Neff / 3)^(1 / 4)
    return 15 / π^4 * Γν^4 * Ωγ0 * (-4 * F_interpolant(_get_y(mν, a)) / a^5 +
                                    dFdy_interpolant(_get_y(mν, a)) / a^4 * (mν / kB / Tν))
end

"""
    _dΩνE2da(a, Ωγ0, mν::AbstractVector; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)

Calculates the derivative of the neutrino energy density parameter [`_ΩνE2`](@ref)
with respect to the scale factor `a`, for a *vector* of neutrino masses.

This function computes the derivative of the expression for `_ΩνE2` by summing
the derivatives of the contributions from each individual neutrino mass. It uses
the [`_F(y)`](@ref) and [`_dFdy(y)`](@ref) functions for each mass.

# Arguments
- `a`: The scale factor.
- `Ωγ0`: The photon density parameter today.
- `mν`: A vector of neutrino masses (`AbstractVector`).

# Keyword Arguments
- `kB`: Boltzmann constant (default: 8.617342e-5 eV/K).
- `Tν`: Neutrino temperature (default: 0.71611 * 2.7255 K).
- `Neff`: Effective number of neutrino species (default: 3.044).

# Returns
The calculated total derivative `d(ΩνE2)/da` at scale factor `a` for the sum
of contributions from all masses in the vector.

# Details
The calculation sums the derivatives of the individual neutrino mass contributions
to `_ΩνE2` with respect to `a`.

# See Also
- [`_ΩνE2(a, Ωγ0, mν::AbstractVector)`](@ref): The function whose derivative is calculated.
- [`_get_y(mν, a)`](@ref): Calculates the `y` parameter for each mass.
- [`_F(y)`](@ref): The integral function used as `F_interpolant`.
- [`_dFdy(y)`](@ref): The function used as `dFdy_interpolant`.
- [`_dΩνE2da(a, Ωγ0, mν)`](@ref): Method for a single neutrino mass.
"""
function _dΩνE2da(a, Ωγ0, mν::AbstractVector; kB=8.617342e-5, Tν=0.71611 * 2.7255, Neff=3.044)
    Γν = (4 / 11)^(1 / 3) * (Neff / 3)^(1 / 4)
    sum_interpolant = 0.0
    for mymν in mν
        sum_interpolant += -4 * F_interpolant(_get_y(mymν, a)) / a^5 +
                           dFdy_interpolant(_get_y(mymν, a)) / a^4 * (mymν / kB / Tν)
    end
    return 15 / π^4 * Γν^4 * Ωγ0 * sum_interpolant
end

"""
    _a_z(z)

Calculates the cosmological scale factor `a` from the redshift `z`.

The relationship between scale factor and redshift is given by ``a = 1 / (1 + z)``.

# Arguments
- `z`: The redshift (scalar or array).

# Returns
The corresponding scale factor `a` (scalar or array).

# Formula
The formula used is:
``a = 1 / (1 + z)``
"""
function _a_z(z)
    return @. 1 / (1 + z)
end

"""
    _ρDE_a(a, w0, wa)

Calculates the evolution of the dark energy density parameter relative to its value today,
as a function of the scale factor `a`.

This function implements the standard parametrization for the dark energy equation of state
`w(a) = w0 + wa*(1-a)`.

# Arguments
- `a`: The scale factor (scalar or array).
- `w0`: The present-day value of the dark energy equation of state parameter.
- `wa`: The derivative of the dark energy equation of state parameter with respect to `(1-a)`.

# Returns
The dark energy density parameter relative to its value today, `ρ_DE(a) / ρ_DE(a=1)`,
at the given scale factor `a` (scalar or array).

# Formula
The formula used is:
``\\rho_\\mathrm{DE}(a) / \\rho_\\mathrm{DE}(a=1) = a^(-3 * (1 + w0 + wa)) * e^{3 * wa * (a - 1)}``

This function uses broadcasting (`@.`) to handle scalar or array inputs for `a`.

# See Also
- [`_ρDE_z(z, w0, wa)`](@ref): Calculates the dark energy density evolution as a function of redshift `z`.
"""
function _ρDE_a(a, w0, wa)
    return a^(-3.0 * (1.0 + w0 + wa)) * exp(3.0 * wa * (a - 1))
end

"""
    _ρDE_z(z, w0, wa)

Calculates the evolution of the dark energy density parameter relative to its value today,
as a function of the redshift `z`.

This function implements the standard parametrization for the dark energy equation of state
``w(a) = w0 + wa*(1-a)``, converted to depend on redshift `z`.

# Arguments
- `z`: The redshift (scalar or array).
- `w0`: The present-day value of the dark energy equation of state parameter.
- `wa`: The derivative of the dark energy equation of state parameter with respect to `(1-a)`.

# Returns
The dark energy density parameter relative to its value today, `ρ_DE(z) / ρ_DE(z=0)`,
at the given redshift `z` (scalar or array).

# Formula
The formula used is:
``\\rho_\\mathrm{DE}(z) / \\rho_\\mathrm{DE}(z=0) = (1 + z)^(3 * (1 + w0 + wa)) * e^{-3 * wa * z / (1 + z)}``

This function uses broadcasting (`@.`) to handle scalar or array inputs for `z`.

# See Also
- [`_ρDE_a(a, w0, wa)`](@ref): Calculates the dark energy density evolution as a function of scale factor `a`.
"""
function _ρDE_z(z, w0, wa)
    return (1 + z)^(3.0 * (1.0 + w0 + wa)) * exp(-3.0 * wa * z / (1 + z))
end

"""
    _dρDEda(a, w0, wa)

Calculates the derivative of the dark energy density parameter evolution,
`d(ρ_DE(a)/ρ_DE(a=1))/da`, with respect to the scale factor `a`.

This function computes the derivative of the formula implemented in [`_ρDE_a(a, w0, wa)`](@ref).

# Arguments
- `a`: The scale factor (scalar or array).
- `w0`: The present-day value of the dark energy equation of state parameter.
- `wa`: The derivative of the dark energy equation of state parameter with respect to `(1-a)`.

# Returns
The calculated derivative of the dark energy density parameter evolution with respect to `a`
at the given scale factor `a` (scalar or array).

# Formula
The formula used is:
`` \\frac{d}{da} \\left( \\frac{\\rho_{\\text{DE}}(a)}{\\rho_{\\text{DE}}(a=1)} \\right) = 3 \\left( -\\frac{1 + w_0 + w_a}{a} + w_a \\right) \\frac{\\rho_{\\text{DE}}(a)}{\\rho_{\\text{DE}}(a=1)} ``

This function uses broadcasting (`@.`) to handle scalar or array inputs for `a`.

# See Also
- [`_ρDE_a(a, w0, wa)`](@ref): Calculates the dark energy density evolution.
"""
function _dρDEda(a, w0, wa)
    return 3 * (-(1 + w0 + wa) / a + wa) * _ρDE_a(a, w0, wa)
end

"""
    _E_a(a, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the normalized Hubble parameter, `E(a)`, at a given scale factor `a`.

`E(a)` describes the expansion rate of the universe relative to the Hubble constant today,
incorporating contributions from different energy density components: radiation (photons
and massless neutrinos), cold dark matter and baryons, dark energy, and massive neutrinos.

# Arguments
- `a`: The scale factor (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: The total neutrino mass (or a vector of masses), used in the calculation of the
        massive neutrino energy density. Defaults to 0.0 (massless neutrinos).
- `w0`: The present-day value of the dark energy equation of state parameter `w(a) = w0 + wa*(1-a)`. Defaults to -1.0 (ΛCDM).
- `wa`: The derivative of the dark energy equation of state parameter with respect to `(1-a)`. Defaults to 0.0 (ΛCDM).

# Returns
The calculated normalized Hubble parameter `E(a)` (scalar or array).

# Details
The calculation includes:
- Photon density `Ωγ0 = 2.469e-5 / h^2`.
- Massless neutrino density `Ων0` (calculated from `_ΩνE2` at a=1).
- Dark energy density `ΩΛ0` (calculated to ensure a flat universe: `1 - Ωγ0 - Ωcb0 - Ων0`).
- Massive neutrino density `_ΩνE2(a, Ωγ0, mν)`.
- Dark energy evolution `_ρDE_a(a, w0, wa)` (density relative to today's dark energy density).

The formula used is:
`E(a) = sqrt(Ωγ0 * a^-4 + Ωcb0 * a^-3 + ΩΛ0 * ρDE(a) + ΩνE2(a))`
where `ρDE(a)` is the dark energy density relative to its value today, and `ΩνE2(a)`
is the massive neutrino energy density parameter at scale factor `a`.

This function uses broadcasting (`@.`) to handle scalar or array inputs for `a`.

# See Also
- [`_ΩνE2(a, Ωγ0, mν)`](@ref): Calculates the massive neutrino energy density.
- [`_ρDE_a(a, w0, wa)`](@ref): Calculates the dark energy density evolution (relative to today).
- [`_E_a(a, w0wacosmo::w0waCDMCosmology)`](@ref): Convenience method using a cosmology struct.
"""
function _E_a(a, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    Ωγ0 = 2.469e-5 / h^2
    Ων0 = _ΩνE2(1.0, Ωγ0, mν)
    ΩΛ0 = 1.0 - (Ωγ0 + Ωcb0 + Ων0)
    return @. sqrt(Ωγ0 * a^-4 + Ωcb0 * a^-3 + ΩΛ0 * _ρDE_a(a, w0, wa) + _ΩνE2(a, Ωγ0, mν))
end

"""
    _E_a(a, w0wacosmo::w0waCDMCosmology)

Calculates the normalized Hubble parameter, `E(a)`, at a given scale factor `a`,
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the main `_E_a` function. It extracts
the cold dark matter and baryon density (`Ωcb0`), Hubble parameter (`h`), neutrino
mass (`mν`), and dark energy parameters (`w0`, `wa`) from the provided cosmology struct
and passes them to the primary `_E_a` method.

# Arguments
- `a`: The scale factor (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated normalized Hubble parameter `E(a)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref): The primary method that performs the calculation.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
"""
function _E_a(a, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _E_a(a, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _E_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the normalized Hubble parameter, `E(z)`, as a function of redshift `z`.

This function is the redshift-dependent counterpart to [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref).
It first converts `z` to the scale factor `a` using [`_a_z(z)`](@ref) and then calls the
`_E_a` function.

# Arguments
- `z`: The redshift (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated normalized Hubble parameter `E(z)` (scalar or array).

# See Also
- [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref): The corresponding scale factor dependent function.
- [`_a_z(z)`](@ref): Converts redshift to scale factor.
- [`_E_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _E_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    a = _a_z(z)
    return _E_a(a, Ωcb0, h; mν=mν, w0=w0, wa=wa)
end

"""
    _E_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the normalized Hubble parameter, `E(z)`, as a function of redshift `z`,
using parameters extracted from a `w0waCDMCosmology` struct.

This function is the redshift-dependent counterpart to [`_E_a(a, w0wacosmo::w0waCDMCosmology)`](@ref).
It's a convenience method that extracts parameters from the struct and calls the primary
[`_E_z(z, Ωcb0, h; mν, w0, wa)`](@ref) method.

# Arguments
- `z`: The redshift (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated normalized Hubble parameter `E(z)` (scalar or array).

# See Also
- [`_E_a(a, w0wacosmo::w0waCDMCosmology)`](@ref): The corresponding scale factor dependent function using a struct.
- [`_E_z(z, Ωcb0, h; mν, w0, wa)`](@ref): The primary method using individual parameters.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
"""
function _E_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _E_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _dlogEdloga(a, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the logarithmic derivative of the normalized Hubble parameter, ``\\frac{d(\\log E)}{d(\\log a)}``,
with respect to the logarithm of the scale factor `a`.

This quantity is useful in cosmological calculations, particularly when analyzing the
growth of structure. It is derived from the derivative of `E(a)` with respect to `a`.

# Arguments
- `a`: The scale factor (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated value of ``\\frac{d(\\log E)}{d(\\log a)}`` at the given scale factor `a` (scalar or array).

# Details
The calculation involves the derivative of the `_E_a` function with respect to `a`.
The formula is derived from `` \\frac{d(\\log E)}{d(\\log a)} = \\frac{a}{E} \\frac{dE}{da} ``. The derivative
`dE/da` involves terms related to the derivatives of the density components with
respect to `a`, including [`_dρDEda(a, w0, wa)`](@ref) and [`_dΩνE2da(a, Ωγ0, mν)`](@ref).

This function uses broadcasting (`@.`) to handle scalar or array inputs for `a`.

# See Also
- [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref): The normalized Hubble parameter function.
- [`_dΩνE2da(a, Ωγ0, mν)`](@ref): Derivative of the neutrino energy density.
- [`_ρDE_a(a, w0, wa)`](@ref): Dark energy density evolution (relative to today).
- [`_dρDEda(a, w0, wa)`](@ref): Derivative of the dark energy density evolution (relative to today).
"""
function _dlogEdloga(a, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    Ωγ0 = 2.469e-5 / h^2
    Ων0 = _ΩνE2(1.0, Ωγ0, mν)
    ΩΛ0 = 1.0 - (Ωγ0 + Ωcb0 + Ων0)
    return a * 0.5 / (_E_a(a, Ωcb0, h; mν=mν, w0=w0, wa=wa)^2) *
           (-3(Ωcb0)a^-4 - 4Ωγ0 * a^-5 + ΩΛ0 * _dρDEda(a, w0, wa) + _dΩνE2da(a, Ωγ0, mν))
end

"""
    _Ωma(a, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the total matter density parameter, `Ω_m(a)`, at a given scale factor `a`.

This represents the combined density of cold dark matter and baryons relative to the
critical density at scale factor `a`.

# Arguments
- `a`: The scale factor (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es) (used in the calculation of `_E_a`).
- `w0`: Dark energy equation of state parameter (used in the calculation of `_E_a`).
- `wa`: Dark energy equation of state parameter derivative (used in the calculation of `_E_a`).

# Returns
The calculated total matter density parameter `Ω_m(a)` at the given scale factor `a` (scalar or array).

# Formula
The formula used is:
`` \\Omega_m(a) = \\frac{\\Omega_{\\text{cb}0} a^{-3}}{E(a)^2} ``
where `` E(a) `` is the normalized Hubble parameter calculated using [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref).

This function uses broadcasting (`@.`) to handle scalar or array inputs for `a`.

# See Also
- [`_E_a(a, Ωcb0, h; mν, w0, wa)`](@ref): The normalized Hubble parameter function.
- [`_Ωma(a, w0wacosmo::w0waCDMCosmology)`](@ref): Convenience method using a cosmology struct.
"""
function _Ωma(a, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return Ωcb0 * a^-3 / (_E_a(a, Ωcb0, h; mν=mν, w0=w0, wa=wa))^2
end

"""
    _Ωma(a, w0wacosmo::w0waCDMCosmology)

Calculates the total matter density parameter, `Ω_m(a)`, at a given scale factor `a`,
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_Ωma(a, Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the cold dark matter and baryon density (`Ωcb0`), Hubble parameter (`h`),
neutrino mass (`mν`), and dark energy parameters (`w0`, `wa`) from the provided cosmology
struct and passes them to the primary `_Ωma` method.

# Arguments
- `a`: The scale factor (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated total matter density parameter `Ω_m(a)` at the given scale factor `a` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_Ωma(a, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_Ωma(a, Ωcb0, h; mν, w0, wa)`](@ref): The primary method that performs the calculation.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
"""
function _Ωma(a, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _Ωma(a, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _r̃_z_check(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the conformal distance `r̃(z)` to a given redshift `z` using numerical integration.

This is a "check" version, typically slower but potentially more accurate, used for verifying
results from faster methods. The conformal distance is the integral of `1/E(z)` with respect to `z`.

# Arguments
- `z`: The redshift (scalar).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated conformal distance `r̃(z)` (scalar).

# Details
The function calculates the integral `` \\int_0^z \\frac{dz'}{E(z')} `` where `` E(z') `` is the
normalized Hubble parameter at redshift `` z' ``, calculated using [`_E_a`](@ref) after converting
`` z' `` to scale factor using [`_a_z`](@ref).
The integration is performed using `IntegralProblem` and the `QuadGKJL()` solver.

# Formula
The conformal distance is defined as:
`` \\tilde{r}(z) = \\int_0^z \\frac{dz'}{E(z')} ``

# See Also
- [`_r̃_z`](@ref): The standard, faster method for calculating conformal distance.
- [`_E_a`](@ref): Calculates the normalized Hubble parameter as a function of scale factor.
- [`_a_z`](@ref): Converts redshift to scale factor.
- [`_r_z_check`](@ref): Calculates the comoving distance using this check version.
"""
function _r̃_z_check(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    p = [Ωcb0, h, mν, w0, wa]
    f(x, p) = 1 / _E_a(_a_z(x), p[1], p[2]; mν=p[3], w0=p[4], wa=p[5])
    domain = (zero(eltype(z)), z) # (lb, ub)
    prob = IntegralProblem(f, domain, p; reltol=1e-12)
    sol = solve(prob, QuadGKJL())[1]
    return sol
end
function _r̃s_z_check(z, ωb0, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    p = [Ωcb0, h, mν, w0, wa, ωb0]
    f(x, p) = (1/sqrt(3*(1+((3.0328e4)*p[6]/(1+x))))) / _E_a(_a_z(x), p[1], p[2]; mν=p[3], w0=p[4], wa=p[5])
    domain = (z, convert(typeof(z), 1.0e7)) # (lb, ub)
    prob = IntegralProblem(f, domain, p; reltol=1e-10)
    sol = solve(prob, QuadGKJL())[1]
    return sol
end

"""
    _r̃_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the conformal distance `r̃(z)` to a given redshift `z` using Gauss-Legendre quadrature.

This is the standard, faster method for calculating the conformal distance, which is the
integral of `1/E(z)` with respect to `z`.

# Arguments
- `z`: The redshift (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated conformal distance `r̃(z)` (scalar or array).

# Details
The function approximates the integral `` \\int_0^z \\frac{dz'}{E(z')} `` using Gauss-Legendre
quadrature with a specified number of points (here, 9). It uses [`_transformed_weights`](@ref)
to get the quadrature points and weights over the interval `[0, z]`. The integrand
`` 1/E(z') `` is evaluated at these points using [`_E_a`](@ref) (after converting `z'` to `a`
with [`_a_z`](@ref)), and the result is a weighted sum.

# Formula
The conformal distance is defined as:
`` \\tilde{r}(z) = \\int_0^z \\frac{dz'}{E(z')} ``
This function computes this integral numerically.

# See Also
- [`_r̃_z_check`](@ref): A slower, check version using different integration.
- [`_E_a`](@ref): Calculates the normalized Hubble parameter as a function of scale factor.
- [`_a_z`](@ref): Converts redshift to scale factor.
- [`_transformed_weights`](@ref): Generates quadrature points and weights.
- [`_r_z`](@ref): Calculates the comoving distance.
- [`_r̃_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _r̃_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    z_array, weigths_array = _transformed_weights(FastGaussQuadrature.gausslegendre, 9, 0, z)
    integrand_array = 1.0 ./ _E_a(_a_z(z_array), Ωcb0, h; mν=mν, w0=w0, wa=wa)
    return dot(weigths_array, integrand_array)
end
function _r̃s_z(z, ωb0, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    z_array, weigths_array = FastGaussQuadrature.gausslaguerre(16)
    reparam_z_array = z_array .+ z
    R_z = (3.0328e4)*ωb0 ./ (1 .+ reparam_z_array)
    fac_R_z = 1 ./ sqrt.(3 .* (1 .+ R_z))
    integrand_array = fac_R_z ./ _E_a(_a_z(reparam_z_array), Ωcb0, h; mν=mν, w0=w0, wa=wa)
    I = dot(weigths_array, exp.(z_array) .* integrand_array)
    return I
end

"""
    _r̃_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the conformal distance `r̃(z)` to a given redshift `z`, using parameters
extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_r̃_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the necessary cosmological parameters from the provided struct.

# Arguments
- `z`: The redshift (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated conformal distance `r̃(z)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_r̃_z(z, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_r̃_z(z, Ωcb0, h; mν, w0, wa)`](@ref): The primary method for calculating conformal distance.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
- [`_r_z`](@ref): Calculates the comoving distance.
"""
function _r̃_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _r̃_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _r_z_check(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the comoving distance `r(z)` to a given redshift `z` using the "check" version
of the conformal distance calculation.

The comoving distance is related to the conformal distance by a factor involving the
speed of light and the Hubble parameter today. This version uses the slower, potentially
more accurate [`_r̃_z_check`](@ref) for the conformal distance.

# Arguments
- `z`: The redshift (scalar).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated comoving distance `r(z)` (scalar).

# Details
The comoving distance is calculated by scaling the conformal distance obtained from
[`_r̃_z_check(z, Ωcb0, h; mν, w0, wa)`](@ref) by the factor `` c_0 / (100 h) ``, where `` c_0 ``
is the speed of light (in units consistent with `h`).

# Formula
The comoving distance is defined as:
`` r(z) = \\frac{c_0}{100 h} \\tilde{r}(z) ``
This function uses `` \\tilde{r}(z) = \\text{_r̃_z_check}(z, \\dots) ``.

# See Also
- [`_r̃_z_check`](@ref): The slower, check version of the conformal distance calculation.
- [`_r_z`](@ref): The standard, faster method for calculating comoving distance.
"""
function _r_z_check(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return c_0 * _r̃_z_check(z, Ωcb0, h; mν=mν, w0=w0, wa=wa) / (100 * h)
end
function _rs_z_check(z, ωb0, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return c_0 * _r̃s_z_check(z, ωb0, Ωcb0, h; mν=mν, w0=w0, wa=wa) / (100 * h)
end

"""
    _r_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the comoving distance `r(z)` to a given redshift `z` using the standard
conformal distance calculation.

The comoving distance is related to the conformal distance by a factor involving the
speed of light and the Hubble parameter today. This version uses the standard, faster
[`_r̃_z`](@ref) for the conformal distance.

# Arguments
- `z`: The redshift (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated comoving distance `r(z)` (scalar or array).

# Details
The comoving distance is calculated by scaling the conformal distance obtained from
[`_r̃_z(z, Ωcb0, h; mν, w0, wa)`](@ref) by the factor `` c_0 / (100 h) ``, where `` c_0 ``
is the speed of light (in units consistent with `h`).

# Formula
The comoving distance is defined as:
`` r(z) = \\frac{c_0}{100 h} \\tilde{r}(z) ``
This function uses `` \\tilde{r}(z) = \\text{_r̃_z}(z, \\dots) ``.

# See Also
- [`_r̃_z`](@ref): The standard, faster method for calculating conformal distance.
- [`_r_z_check`](@ref): A slower, check version using a different conformal distance calculation.
- [`_r_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _r_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return c_0 * _r̃_z(z, Ωcb0, h; mν=mν, w0=w0, wa=wa) / (100 * h)
end
function _rs_z(z, ωb0, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return c_0 * _r̃s_z(z, ωb0, Ωcb0, h; mν=mν, w0=w0, wa=wa) / (100 * h)
end

"""
    _r_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the comoving distance `r(z)` to a given redshift `z`, using parameters
extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_r_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the necessary cosmological parameters from the provided struct.

# Arguments
- `z`: The redshift (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated comoving distance `r(z)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_r_z(z, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_r_z(z, Ωcb0, h; mν, w0, wa)`](@ref): The primary method for calculating comoving distance.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
- [`_r̃_z`](@ref): Calculates the conformal distance.
"""
function _r_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _r_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _d̃A_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the conformal angular diameter distance `d̃_A(z)` to a given redshift `z`.

The conformal angular diameter distance is defined as the conformal comoving distance
divided by `(1 + z)`.

# Arguments
- `z`: The redshift (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated conformal angular diameter distance `d̃_A(z)` (scalar or array).

# Details
The function calculates the conformal comoving distance using [`_r̃_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
and then divides by `(1 + z)`.

# Formula
The formula used is:
`` \\tilde{d}_A(z) = \\frac{\\tilde{r}(z)}{1 + z} ``
where `` \\tilde{r}(z) `` is the conformal comoving distance.

# See Also
- [`_r̃_z`](@ref): Calculates the conformal comoving distance.
- [`_dA_z`](@ref): Calculates the standard angular diameter distance.
- [`_d̃A_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _d̃A_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return _r̃_z(z, Ωcb0, h; mν=mν, w0=w0, wa=wa) / (1 + z)
end

"""
    _d̃A_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the conformal angular diameter distance `d̃_A(z)` to a given redshift `z`,
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_d̃A_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the necessary cosmological parameters from the provided struct.

# Arguments
- `z`: The redshift (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated conformal angular diameter distance `d̃_A(z)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_d̃A_z(z, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_d̃A_z(z, Ωcb0, h; mν, w0, wa)`](@ref): The primary method for calculating conformal angular diameter distance.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
- [`_dA_z`](@ref): Calculates the standard angular diameter distance.
"""
function _d̃A_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _d̃A_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _dA_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the angular diameter distance `d_A(z)` to a given redshift `z`.

The angular diameter distance is defined as the comoving distance divided by `(1 + z)`.

# Arguments
- `z`: The redshift (scalar or array).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated angular diameter distance `d_A(z)` (scalar or array).

# Details
The function calculates the comoving distance using [`_r_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
and then divides by `(1 + z)`.

# Formula
The formula used is:
`` d_A(z) = \\frac{r(z)}{1 + z} ``
where `` r(z) `` is the comoving distance.

# See Also
- [`_r_z`](@ref): Calculates the comoving distance.
- [`_a_z`](@ref): Converts redshift to scale factor.
- [`_d̃A_z`](@ref): Calculates the conformal angular diameter distance.
- [`_dA_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _dA_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    return _r_z(z, Ωcb0, h; mν=mν, w0=w0, wa=wa) / (1 + z)
end

"""
    _dA_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the angular diameter distance `d_A(z)` to a given redshift `z`,
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_dA_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the necessary cosmological parameters from the provided struct.

# Arguments
- `z`: The redshift (scalar or array).
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated angular diameter distance `d_A(z)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_dA_z(z, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_dA_z(z, Ωcb0, h; mν, w0, wa)`](@ref): The primary method for calculating angular diameter distance.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
- [`_d̃A_z`](@ref): Calculates the conformal angular diameter distance.
"""
function _dA_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _dA_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _growth!(du, u, p, loga)

Defines the in-place right-hand side of the second-order ordinary differential equation
for the linear growth factor `D(a)`, with `log(a)` as the independent variable.

The state vector `u` is `[D(log a), dD/d(log a)]`. This function calculates the derivatives
`du = [dD/d(log a), d^2D/d(log a)^2]` based on the growth equation.

# Arguments
- `du`: The output vector where the calculated derivatives are stored (modified in-place).
- `u`: The current state vector `[D(log a), dD/d(log a)]`.
- `p`: A vector of parameters `[Ωcb0, mν, h, w0, wa]`.
- `loga`: The natural logarithm of the scale factor, `log(a)`.

# Returns
Modifies the `du` vector in-place.

# Details
The function solves the second-order differential equation for the linear growth factor,
often written as:
```math
\\frac{d^2 D}{d(\\ln a)^2} + \\left(2 + \\frac{d \\ln E}{d \\ln a}\\right) \\frac{d D}{d \\ln a} - \\frac{3}{2} \\Omega_m(a) D = 0
```
where `` E(a) `` is the normalized Hubble parameter and `` \\Omega_m(a) `` is the matter density
parameter.

The terms `` \\frac{d \\ln E}{d \\ln a} `` and `` \\Omega_m(a) `` are calculated using
[`_dlogEdloga`](@ref) and [`_Ωma`](@ref) respectively, with parameters extracted from `p`.

The system of first-order ODEs implemented is:
`` \\frac{d u[1]}{d(\\ln a)} = u[2] ``
`` \\frac{d u[2]}{d(\\ln a)} = -\\left(2 + \\frac{d \\ln E}{d \\ln a}\\right) u[2] + \\frac{3}{2} \\Omega_m(a) u[1] ``

# See Also
- [`_growth_solver`](@ref): Functions that solve this ODE.
- [`_dlogEdloga`](@ref): Calculates the logarithmic derivative of E(a).
- [`_Ωma`](@ref): Calculates the matter density parameter at scale factor a.
- [`_E_a`](@ref): Related normalized Hubble parameter.
"""
function _growth!(du, u, p, loga)
    Ωcb0 = p[1]
    mν = p[2]
    h = p[3]
    w0 = p[4]
    wa = p[5]
    a = exp(loga)
    D = u[1]
    dD = u[2]
    du[1] = dD
    du[2] = -(2 + _dlogEdloga(a, Ωcb0, h; mν=mν, w0=w0, wa=wa)) * dD +
            1.5 * _Ωma(a, Ωcb0, h; mν=mν, w0=w0, wa=wa) * D
end

"""
    _growth_solver(Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Solves the ODE for the linear growth factor `D(a)` and its derivative `dD/d(log a)`
over a fixed range of `log(a)`, typically from an early time to slightly past `a=1`.

This function sets up and solves the [`_growth!`](@ref) ODE using a standard solver.

# Arguments
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
A DifferentialEquations.jl solution object containing the values of `D(log a)` and
`dD/d(log a)` over the solved `log(a)` range.

# Details
The ODE is solved from `log(amin)` to `log(1.01)`, where `amin = 1/139`.
Initial conditions `u₀ = [amin, amin]` are used, corresponding to `D(a) ≈ a` at early times.
The problem is solved using the `Tsit5()` solver with a relative tolerance of `1e-5`.

# See Also
- [`_growth!`](@ref): Defines the growth ODE.
- [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref): Method to solve and save at specific redshifts.
- [`_growth_solver(w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _growth_solver(Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    amin = 1 / 139
    u₀ = [amin, amin]

    logaspan = (log(amin), log(1.01))#to ensure we cover the relevant range

    p = [Ωcb0, mν, h, w0, wa]

    prob = ODEProblem(_growth!, u₀, logaspan, p)

    sol = solve(prob, Tsit5(), reltol=1e-5; verbose=false)
    return sol
end

"""
    _growth_solver(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Solves the ODE for the linear growth factor `D(a)` and its derivative `dD/d(log a)`
and returns the solution evaluated specifically at the given redshift(s) `z`.

This function solves the [`_growth!`](@ref) ODE over a range of `log(a)` and then extracts
the solution values corresponding to the provided redshift(s).

# Arguments
- `z`: The redshift or an array of redshifts at which to save the solution.
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
A 2xN array (where N is the number of redshifts in `z`) containing the solution.
The first row contains the growth factor `D(z)`, and the second row contains
the derivative `dD/d(log a)` evaluated at redshift `z`.

# Details
The ODE is solved from `log(amin)` to `log(1.01)`, where `amin = 1/139`.
Initial conditions `u₀ = [amin, amin]` are used, corresponding to `D(a) ≈ a` at early times.
The problem is solved using the `Tsit5()` solver with a relative tolerance of `1e-5`.
The solution is saved specifically at the `log(a)` values corresponding to the input
redshifts `z`, obtained using [`_a_z`](@ref).

# See Also
- [`_growth!`](@ref): Defines the growth ODE.
- [`_growth_solver(Ωcb0, h; mν, w0, wa)`](@ref): Method to solve over a fixed range.
- [`_growth_solver(w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
- [`_a_z`](@ref): Converts redshift to scale factor.
"""
function _growth_solver(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    amin = 1 / 139
    loga = vcat(log.(_a_z.(z)))
    u₀ = [amin, amin]

    logaspan = (log(amin), log(1.01))#to ensure we cover the relevant range

    p = [Ωcb0, mν, h, w0, wa]

    prob = ODEProblem(_growth!, u₀, logaspan, p)

    sol = solve(prob, Tsit5(), reltol=1e-5; saveat=loga)[1:2, :]
    return sol
end

"""
    _growth_solver(w0wacosmo::w0waCDMCosmology)

Solves the ODE for the linear growth factor `D(a)` and its derivative `dD/d(log a)`
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_growth_solver(Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the necessary cosmological parameters from the provided struct.

# Arguments
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
A DifferentialEquations.jl solution object containing the values of `D(log a)` and
`dD/d(log a)` over the solved `log(a)` range.

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_growth_solver(Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_growth!`](@ref): Defines the growth ODE.
- [`_growth_solver(Ωcb0, h; mν, w0, wa)`](@ref): The primary solver method.
- [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref): Method to solve and save at specific redshifts.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
"""
function _growth_solver(w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _growth_solver(Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _D_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the linear growth factor `D(z)` for a single redshift `z`.

The linear growth factor describes how density perturbations grow in the linear regime
of structure formation. It is obtained by solving a second-order ODE.

# Arguments
- `z`: The redshift (scalar).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated linear growth factor `D(z)` (scalar).

# Details
This function solves the growth ODE using the [`_growth_solver(Ωcb0, h; mν, w0, wa)`](@ref)
method, which solves over a fixed range of `log(a)`. It then evaluates the solution
at the `log(a)` value corresponding to the input redshift `z` (obtained via [`_a_z`](@ref))
to get the value of `D(z)`.

# See Also
- [`_growth_solver`](@ref): Solves the growth ODE.
- [`_a_z`](@ref): Converts redshift to scale factor.
- [`_D_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref): Method for a vector of redshifts.
- [`_D_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _growth_solver(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _growth_solver(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _growth_solver(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Solves the ODE for the linear growth factor `D(a)` and its derivative `dD/d(log a)`
and returns the solution evaluated specifically at the given redshift(s) `z`.

This function solves the [`_growth!`](@ref) ODE over a range of `log(a)` and then extracts
the solution values corresponding to the provided redshift(s).

# Arguments
- `z`: The redshift or an array of redshifts at which to save the solution.
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
A 2xN array (where N is the number of redshifts in `z`) containing the solution.
The first row contains the growth factor `D(z)`, and the second row contains
the derivative `dD/d(log a)` evaluated at redshift `z`.

# Details
The ODE is solved from `log(amin)` to `log(1.01)`, where `amin = 1/139`.
Initial conditions `u₀ = [amin, amin]` are used, corresponding to `D(a) ≈ a` at early times.
The problem is solved using the `Tsit5()` solver with a relative tolerance of `1e-5`.
The solution is saved specifically at the `log(a)` values corresponding to the input
redshifts `z`, obtained using [`_a_z`](@ref).

# See Also
- [`_growth!`](@ref): Defines the growth ODE.
- [`_growth_solver(Ωcb0, h; mν, w0, wa)`](@ref): Method to solve over a fixed range.
- [`_growth_solver(w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
- [`_a_z`](@ref): Converts redshift to scale factor.
"""
function _D_z(z, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    sol = _growth_solver(Ωcb0, h; mν=mν, w0=w0, wa=wa)
    return (sol(log(_a_z(z)))[1, :])[1, 1][1]
end

"""
    _D_z(z::AbstractVector, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)

Calculates the linear growth factor `D(z)` for a vector of redshifts `z`.

The linear growth factor describes how density perturbations grow in the linear regime
of structure formation. It is obtained by solving a second-order ODE.

# Arguments
- `z`: A vector of redshifts (`AbstractVector`).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
A vector containing the calculated linear growth factor `D(z)` for each redshift in the input vector `z`.

# Details
This function solves the growth ODE using the [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref)
method, which solves the ODE and saves the solution specifically at the `log(a)` values
corresponding to the input redshifts `z`. It then extracts the first row of the solution
(which contains the `D(z)` values) and reverses it.

# See Also
- [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref): Solves the growth ODE and saves at specific redshifts.
- [`_a_z`](@ref): Converts redshift to scale factor (used internally by `_growth_solver`).
- [`_D_z(z, Ωcb0, h; mν, w0, wa)`](@ref): Method for a single redshift.
- [`_D_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _D_z(z::AbstractVector, Ωcb0, h; mν=0.0, w0=-1.0, wa=0.0)
    sol = _growth_solver(z, Ωcb0, h; mν=mν, w0=w0, wa=wa)
    return reverse(sol[1, 1:end])
end

"""
    _D_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the linear growth factor `D(z)` for a given redshift or vector of redshifts `z`,
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_D_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
or [`_D_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref) functions. It extracts the
necessary cosmological parameters from the provided struct and calls the appropriate
method based on whether `z` is a scalar or a vector.

# Arguments
- `z`: The redshift or an array of redshifts.
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated linear growth factor `D(z)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls either [`_D_z(z, Ωcb0, h; mν, w0, wa)`](@ref) or [`_D_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref)
internally, depending on the type of `z`.

# See Also
- [`_D_z(z, Ωcb0, h; mν, w0, wa)`](@ref): Method for a single redshift.
- [`_D_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref): Method for a vector of redshifts.
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
"""
function _D_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _D_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _f_z(z::AbstractVector, Ωcb0, h; mν=0, w0=-1.0, wa=0.0)

Calculates the linear growth rate `f(z)` for a vector of redshifts `z`.

The linear growth rate is defined as `` f(z) = \\frac{d \\ln D}{d \\ln a} = \\frac{dD/d(\\ln a)}{D} ``,
where `D(z)` is the linear growth factor and `a` is the scale factor.

# Arguments
- `z`: A vector of redshifts (`AbstractVector`).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
A vector containing the calculated linear growth rate `f(z)` for each redshift in the input vector `z`.

# Details
This function uses the [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref) method to solve
the growth ODE and obtain the growth factor `D(z)` and its derivative with respect to
`log(a)`, `dD/d(log a)`, at the specified redshifts. It then calculates `f(z)` as the
ratio of `dD/d(log a)` to `D(z)` at each redshift. The result is reversed before returning.

# Formula
The formula used is:
`` f(z) = \\frac{d \\ln D}{d \\ln a} = \\frac{dD/d(\\ln a)}{D} ``

# See Also
- [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref): Solves the growth ODE and saves at specific redshifts.
- [`_D_z`](@ref): Calculates the linear growth factor.
- [`_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref): Method for a single redshift.
- [`_f_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
- [`_D_f_z`](@ref): Calculates both D(z) and f(z).
"""
function _f_z(z::AbstractVector, Ωcb0, h; mν=0, w0=-1.0, wa=0.0)
    sol = _growth_solver(z, Ωcb0, h; mν=mν, w0=w0, wa=wa)
    D = sol[1, 1:end]
    D_prime = sol[2, 1:end]#if wanna have normalized_version, 1:end
    result = @. 1 / D * D_prime
    return reverse(result)
end

"""
    _f_z(z, Ωcb0, h; mν=0, w0=-1.0, wa=0.0)

Calculates the linear growth rate `f(z)` for a single redshift `z`.

The linear growth rate is defined as `` f(z) = \\frac{d \\ln D}{d \\ln a} = \\frac{dD/d(\\ln a)}{D} ``,
where `D(z)` is the linear growth factor and `a` is the scale factor.

# Arguments
- `z`: The redshift (scalar).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
The calculated linear growth rate `f(z)` (scalar).

# Details
This function uses the [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref) method to solve
the growth ODE and obtain the growth factor `D(z)` and its derivative with respect to
`log(a)`, `dD/d(log a)`, at the specified redshift. It then calculates `f(z)` as the
ratio of `dD/d(log a)` to `D(z)`.

# Formula
The formula used is:
`` f(z) = \\frac{d \\ln D}{d \\ln a} = \\frac{dD/d(\\ln a)}{D} ``

# See Also
- [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref): Solves the growth ODE and saves at specific redshifts.
- [`_D_z`](@ref): Calculates the linear growth factor.
- [`_f_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref): Method for a vector of redshifts.
- [`_f_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
- [`_D_f_z`](@ref): Calculates both D(z) and f(z).
"""
function _f_z(z, Ωcb0, h; mν=0, w0=-1.0, wa=0.0)
    sol = _growth_solver(z, Ωcb0, h; mν=mν, w0=w0, wa=wa)
    D = sol[1, 1:end][1]
    D_prime = sol[2, 1:end][1]
    return (1/D*D_prime)[1]
end

"""
    _f_z(z, w0wacosmo::w0waCDMCosmology)

Calculates the linear growth rate `f(z)` for a given redshift or vector of redshifts `z`,
using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
or [`_f_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref) functions. It extracts the
necessary cosmological parameters from the provided struct and calls the appropriate
method based on whether `z` is a scalar or a vector.

# Arguments
- `z`: The redshift or an array of redshifts.
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
The calculated linear growth rate `f(z)` (scalar or array).

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls either [`_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref) or [`_f_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref)
internally, depending on the type of `z`.

# See Also
- [`_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref): Method for a single redshift.
- [`_f_z(z::AbstractVector, Ωcb0, h; mν, w0, wa)`](@ref): Method for a vector of redshifts.
- [`w0waCDMCosmology`](@ref): The struct type containing the cosmological parameters.
- [`_D_f_z`](@ref): Calculates both D(z) and f(z).
"""
function _f_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _f_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end

"""
    _D_f_z(z, Ωcb0, h; mν=0, w0=-1.0, wa=0.0)

Calculates both the linear growth factor `D(z)` and the linear growth rate `f(z)`
for a vector of redshifts `z`.

This function is a convenience to get both quantities from a single ODE solution.
The growth rate is defined as `` f(z) = \\frac{d \\ln D}{d \\ln a} = \\frac{dD/d(\\ln a)}{D} ``.

# Arguments
- `z`: A vector of redshifts (`AbstractVector`).
- `Ωcb0`: The density parameter for cold dark matter and baryons today.
- `h`: The Hubble parameter today, divided by 100 km/s/Mpc.

# Keyword Arguments
- `mν`: Total neutrino mass(es).
- `w0`: Dark energy equation of state parameter.
- `wa`: Dark energy equation of state parameter derivative.

# Returns
A tuple `(D_values, f_values)`, where `D_values` is a vector of the linear growth factor
`D(z)` and `f_values` is a vector of the linear growth rate `f(z)` for each redshift
in the input vector `z`. Both vectors are reversed before returning.

# Details
This function uses the [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref) method to solve
the growth ODE and obtain the growth factor `D(z)` and its derivative with respect to
`log(a)`, `dD/d(log a)`, at the specified redshifts. It then calculates `f(z)` as the
ratio of `dD/d(log a)` to `D(z)` at each redshift. Both the `D(z)` and calculated `f(z)`
vectors are returned.

# Formula
The formula used for `f(z)` is:
`` f(z) = \\frac{d \\ln D}{d \\ln a} = \\frac{dD/d(\\ln a)}{D} ``

# See Also
- [`_growth_solver(z, Ωcb0, h; mν, w0, wa)`](@ref): Solves the growth ODE and saves at specific redshifts.
- [`_D_z`](@ref): Calculates the linear growth factor separately.
- [`_f_z`](@ref): Calculates the linear growth rate separately.
- [`_D_f_z(z, w0wacosmo::w0waCDMCosmology)`](@ref): Method using a cosmology struct.
"""
function _D_f_z(z, Ωcb0, h; mν=0, w0=-1.0, wa=0.0)
    sol = _growth_solver(z, Ωcb0, h; mν=mν, w0=w0, wa=wa)
    D = sol[1, 1:end]
    D_prime = sol[2, 1:end]
    f = @. 1 / D * D_prime
    return reverse(D), reverse(f)
end

"""
    _D_f_z(z, w0wacosmo::w0waCDMCosmology)

Calculates both the linear growth factor `D(z)` and the linear growth rate `f(z)`
for a vector of redshifts `z`, using parameters extracted from a `w0waCDMCosmology` struct.

This method is a convenience wrapper around the primary [`_D_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref)
function. It extracts the necessary cosmological parameters from the provided struct.

# Arguments
- `z`: A vector of redshifts.
- `w0wacosmo`: A struct of type `w0waCDMCosmology` containing the cosmological parameters.

# Returns
A tuple `(D_values, f_values)`, where `D_values` is a vector of the linear growth factor
`D(z)` and `f_values` is a vector of the linear growth rate `f(z)` for each redshift
in the input vector `z`.

# Details
The parameters `Ωcb0`, `h`, `mν`, `w0`, and `wa` are extracted from the `w0wacosmo` struct.
`Ωcb0` is calculated as `(w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2`.

This method calls the primary [`_D_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref) method internally.

# See Also
- [`_D_f_z(z, Ωcb0, h; mν, w0, wa)`](@ref): The primary method for calculating D(z) and f(z).
- `w0waCDMCosmology`: The struct type containing the cosmological parameters.
- [`_D_z`](@ref): Calculates the linear growth factor separately.
- [`_f_z`](@ref): Calculates the linear growth rate separately.
"""
function _D_f_z(z, w0wacosmo::w0waCDMCosmology)
    Ωcb0 = (w0wacosmo.ωb + w0wacosmo.ωc) / w0wacosmo.h^2
    return _D_f_z(z, Ωcb0, w0wacosmo.h; mν=w0wacosmo.mν, w0=w0wacosmo.w0, wa=w0wacosmo.wa)
end
