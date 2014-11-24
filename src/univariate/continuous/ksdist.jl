# Distribution of the (two-sided) Kolmogorov-Smirnoff statistic
#   D_n = \sup_x |\hat{F}_n(x) -F(x)|
#   sqrt(n) D_n converges a.s. to the Kolmogorov distribution.
immutable KSDist <: ContinuousUnivariateDistribution
    n::Int
end

# support handling

@distr_support KSDist 1 / (2 * d.n) 1.0

# TODO: implement Simard and L'Ecuyer (2011) meta-algorithm
# requires Pomeranz and Pelz-Good algorithms
function cdf(d::KSDist,x::Float64)
    n = d.n
    b = x*n
    # known exact values
    if b <= 0.5
        return 0.0
    elseif b <= 1.0
        # accuracy could be improved
        return exp(lfact(n)+n*(log(2.0*b-1.0)-log(n)))
    elseif x >= 1.0
        return 1.0
    elseif b >= n-1
        return 1.0 - 2.0*(1.0-x)^n
    end

    a = b*x
    if a >= 18.0
        return 1.0
    elseif n <= 10_000
        if a <= 4.0
            return cdf_durbin(d,x)
        else
            return 1.0 - ccdf_miller(d,x)
        end
    else
        return cdf(Kolmogorov(),sqrt(a))
    end
end

function ccdf(d::KSDist,x::Float64)    
    n = d.n
    b = x*n
    # Ruben and Gambino (1982) known exact values
    if b <= 0.5
        return 1.0
    elseif b <= 1.0
        return 1.0-exp(lfact(n)+n*(log(2.0*b-1.0)-log(n)))
    elseif x >= 1.0
        return 0.0
    elseif b >= n-1
        return 2.0*(1.0-x)^n
    end

    a = b*x
    if a >= 370.0
        return 0.0
    elseif a >= 4.0 || (n > 140 && a >= 2.2)
        return ccdf_miller(d,x)
    else
        return 1.0-cdf(d,x)
    end
end


# Durbin matrix CDF method, based on Marsaglia, Tsang and Wang (2003)
# modified to avoid need for exponent tracking
function cdf_durbin(d::KSDist,x::Float64)
    n = d.n
    k, ch, h = ceil_rems_mult(n,x)

    m = 2*k-1
    H = Array(Float64,m,m)    
    for i = 1:m, j = 1:m
        H[i,j] = i-j+1 >= 0 ? 1.0 : 0.0        
    end
    r = 1.0
    for i = 1:m 
        # (1-h^i) = (1-h)(1+h+...+h^(i-1))
        H[i,1] = H[m,m-i+1] = ch*r
        r += h^i
    end
    H[m,1] += h <= 0.5 ? -h^m : -h^m+(h-ch)
    for i = 1:m, j = 1:m
        for g = 1:max(i-j+1,0)
            H[i,j] /= g
        end
        # we can avoid keeping track of the exponent by dividing by e
        # (from Stirling's approximation)
        H[i,j] /= e
    end
    Q = H^n
    s = Q[k,k]
    s*stirling(n)
end

# Miller (1956) approximation
function ccdf_miller(d::KSDist, x::Real)
    2.0*ccdf(KSOneSided(d.n),x)
end

## these functions are used in durbin and pomeranz algorithms
# calculate exact remainders the easy way
function floor_rems_mult(n,x)
    t = big(x)*big(n)
    fl = floor(t)
    lrem = t - fl
    urem = (fl+one(fl)) - t
    return convert(typeof(n),fl), convert(typeof(x),lrem), convert(typeof(x),urem)
end
function ceil_rems_mult(n,x)
    t = big(x)*big(n)
    cl = ceil(t)
    lrem = t - (cl - one(cl))
    urem = cl - t
    return convert(typeof(n),cl), convert(typeof(x),lrem), convert(typeof(x),urem)
end

# n!*(e/n)^n
function stirling(n)    
    if n < 500
        s = 1.0
        for i = 1:n
            s *= i/n*e 
        end
        return s
    else
        # 3rd-order Stirling's approximation more accurate for large n
        twn = 12.0*n
        return sqrt(2.0*pi*n)*(1.0 + twn\(1 + (2.0*twn)\(1 - (15.0*twn)\139.0)))
    end
end
