
##### applications.

function computemean(x::Vector{T})::T where T <: Real
    
    if isempty(x)
        return zero(T)
    end

    return sum(x)/length(x)
end

# devectorized implementation of Statistics.mean( x).
function computemean(x::Vector{Vector{T}})::Vector{T} where T <: Real
    
    @assert !isempty(x)

    s = zeros(T, length(x[begin]))
    for n in eachindex(x)
        for d in eachindex(x[n])
            s[d] += x[n][d]
        end
    end

    N = length(x)
    for d in eachindex(s)
        s[d] = s[d] / N
    end

    return s
end

"""
function mergepoints(
    X::Vector{Vector{T}},
    metricfunc::Function;
    tol = 1e-6,
    )::Tuple{Vector{Vector{T}},Bool} where T

Same as mergepointfull(), except only returns the merged set of points and whether the specified tolerance was achieved.
"""
function mergepoints(
    X::Vector{Vector{T}},
    metricfunc::Function;
    tol = 1e-6,
    )::Tuple{Vector{Vector{T}},Bool} where T

    points, _, tol_satisfied = mergepoints(X, nothing, metricfunc; tol = tol)
    
    return points, tol_satisfied
end


"""
function mergepoints(
    X::Vector{Vector{T}},
    f_X::Vector{T},
    metricfunc::Function;
    tol = 1e-6,
    )::Tuple{Vector{Vector{T}},Bool} where T

Same as mergepoints(), applies the partition generated by X to every data set in Zs.
"""
function mergepoints(
    X::Vector{Vector{T}},
    f_X::FT,
    metricfunc::Function;
    tol = 1e-6,
    )::Tuple{Vector{Vector{T}}, FT, Bool} where {T, FT <: Union{Vector{T}, Nothing}}

    result = mergepointsfull(
        MergePointInput(X,f_X),
        metricfunc;
        tol = tol,
    )
    
    return result.points, result.scalars, result.tol_satisfied
end


struct MergePointInput{T, FT <: Union{Vector{T}, Nothing}}
    points::Vector{Vector{T}}
    scalars::FT
end

struct MergePointOutput{T, FT <: Union{Vector{T}, Nothing}}
    points::Vector{Vector{T}} # set of merged points.
    scalars::FT # set of merged scalars.
    tol_satisfied::Bool # hether the pair-wise distances in `Y` are all smaller than `tol`.
    sorted_distance_set::Vector{T}
    sorted_partition_set::Vector{Vector{Vector{Int}}}
    index::Int # Y was assembled corresponding to level softed_distance_set[index]
end

function emptyscalararray(::Nothing)::Nothing
    return nothing
end

function emptyscalararray(::Vector{T})::Vector{T} where T
    return Vector{T}(undef, 0)
end

# don't export this. Have doc string for developer documentation.
"""
function mergepointsfull(
    in::MergePointInput{T,FT},
    metricfunc::Function;
    tol = 1e-6,
    )::MergePointOutput{T,FT} where {T, FT <: Union{Vector{T}, Nothing}}

Inputs:
- `X` is the set of points to be merged. This algorithm assumes the points are unique.

- `f_X` is the set of scalars corresonding to `X`.

- `metricfunc` is the metric function used to compute the distance between two points.

- `tol` is the minimum pair-wise distance we desire for the output set of points, `Y`.

Description:
`Y` is the output of `fuseparts(partitioned_set_sorted[chosen_ind])`.
The merging is controlled by the single-linkage clustering on `X`.
The scalar associate with each entry of `X` is `f_X`. The output `Yf_X` corresponds to the scalars for `YX`.
"""
function mergepointsfull(
    in::MergePointInput{T,FT},
    metricfunc::Function;
    tol = 1e-6,
    )::MergePointOutput{T,FT} where {T, FT <: Union{Vector{T}, Nothing}}

    X, f_X = in.points, in.scalars

    @assert tol > zero(T)

    h_set, partition_set = runsinglelinkage(X, metricfunc; early_stop_distance = tol)

    inds = sortperm(h_set, rev = true)

    partitioned_set_sorted = partition_set[inds]
    h_set_sorted = h_set[inds]

    ind = findfirst(xx->xx<tol, h_set_sorted)
    if typeof(ind) <: Nothing
        println("Error with mergepoints(). Returning a copy of the input.")
        return copy(X), copy(Zs)
    end    
    
    # allocate for scope reasons.
    Y = Vector{Vector{T}}(undef, 0)
    Yf_X = emptyscalararray(f_X)
    # Ys = collect(
    #     Vector{ZT}(undef, 0)
    #     for _ in eachindex(Zs)
    # )
    tol_satisfied = false

    while !tol_satisfied && ind > 0

        partition = partitioned_set_sorted[ind] # select partition.
        Y = fuseparts(X, partition)
        
        # for m in eachindex(Ys)
        #     Ys[m] = fuseparts(partition, Zs[m])
        # end
        Yf_X = fuseparts(f_X, partition)

        # note that we need to check for tolerance validity again since we're replacing each part with its centroid, We might violate the tolerance.
        Y_dists = getdistances(Y, metricfunc)
        tol_satisfied = checktoptriangle(Y_dists, tol)

        ind -= 1
    end

    return MergePointOutput(
        Y,
        Yf_X,
        tol_satisfied,
        h_set_sorted,
        partitioned_set_sorted,
        ind+1,
    )
end

# For testing Zs
# # mergepoints using X, but also merge the same entries for datasets contained in Zs.
# Zs = Vector{Vector{Vector{T}}}(undef, 1)
# Zs[begin] = f_X
# Y2, Ys2, status_flag = SingleLinkagePartitions.mergepoints(
#     X,
#     Zs,
#     metricfunc;
#     tol = distance_threshold,
# )
# println("This should be true: ", status_flag)
# println("This should be zero: ", norm(Y-Y2))

# # If there is only one data set, such as f_X in this example, then we can avoid explicitly constructing Zs to contain f_X.
# Y3, Yf_X, status_flag = SingleLinkagePartitions.mergepoints(
#     X,
#     f_X,
#     metricfunc;
#     tol = distance_threshold,
# )
# println("This should be true: ", status_flag)
# println("This should be zero: ", norm(Y-Y3))
# println("This should be zero: ", norm(Ys2[begin]-Yf_X))

"""
fuseparts(
    X::Vector{Vector{T}},
    partition::Vector{Vector{Int}},
    )::Vector{Vector{T}} where T

Description:
A point in the output `Y` is assigned to be the averaging of the points in a part from `partition`, which is a partition of `X`.
"""
function fuseparts(
    #X::Vector{Vector{T}},
    X::Vector{DT},
    partition::Vector{Vector{Int}},
    #)::Vector{Vector{T}} where T <: Real
    )::Vector{DT} where DT

    N_parts = length(partition)
    #Y = Vector{Vector{T}}(undef, N_parts)
    Y = Vector{DT}(undef, N_parts)
    #max_distance_from_tol = Vector{T}(undef, N_parts)
    for k in eachindex(Y)
        
        S = X[partition[k]]
        #out[k] = Statistics.mean(S)
        mean_k = computemean(S) # rid of dependency on Statistics.

        #max_distance_from_tol[k] = maximum( metricfunc(S[i], mean_k) for i in eachindex(S) )
        Y[k] = mean_k
    end

    return Y
end

function fuseparts(::Nothing, args...)::Nothing
    return nothing
end

########## routines for testing.

"""
getdistances(X::Vector{Vector{T}}, metricfunc) where T

Description:
Pair-wise distance of the points in `X`, with respect to the metric in `metricfunc`.
An example of metricfunc is:
```
metricfunc = (xx,yy)->norm(xx-yy)
```
"""
function getdistances(X::Vector{Vector{T}}, metricfunc) where T
    
    K = zeros(T, length(X), length(X))
    for i in eachindex(X)
        for j in eachindex(X) 
            K[i,j] = metricfunc(X[i], X[j])
        end
    end

    return K
end

function checktoptriangle(K::Matrix{T}, lb::T)::Bool where T

    status_flag = true
    for j in axes(K,2)
        for i in Iterators.take(axes(K,1), j-1)
            status_flag = status_flag && (K[i,j] > lb)
            #@show (i,j)
        end
    end

    return status_flag
end

#### utilities

"""
instantiatepartition(
    partition::Vector{Vector{Int}},
    X::Vector{Vector{T}},
    )::Vector{Vector{Vector{T}}} where T

Description:
`partition` is a partition of `X` in terms of indices, which uses less storage than storing it in terms of the contents of `X`.
This function returns a partition of `X` in terms of points that corresponds to `partition`.
"""
function instantiatepartition(
    partition::Vector{Vector{Int}},
    X::Vector{Vector{T}},
    )::Vector{Vector{Vector{T}}} where T

    N_parts = length(partition)
    partition_X = Vector{Vector{Vector{T}}}(undef, N_parts)
    for k in eachindex(partition_X)
        
        partition_X[k] = X[partition[k]]
    end

    return partition_X
end