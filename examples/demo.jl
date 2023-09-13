
using LinearAlgebra

import Random
Random.seed!(25)

import SingleLinkagePartitions

include("./helpers/utils.jl") # replace routines in core.jl with this.



#### singlet-linkage clustering.
T = Float64

metricfunc = (xx,yy)->norm(xx-yy)

#X = collect( randn(3) for _ = 1:10 )
#X = [[-0.40243248293794137, 0.8540414903329187, -0.6651248667822778, -0.9754736537655263, -0.341379056315598, -1.0410555755312705, -1.0496381529964869], [-1.0289732912432703, -0.4305269991795779, 0.7262044632757468, 0.8138894370909177, 0.6104189261116074, 2.0501294946950264, 0.18095967976913974], [0.9406747232875855, 1.0407043988018494, -0.14776493165237461, -0.8737149501414327, 1.0484097740458416, 0.7379871044247477, -0.02494318852134621], [-0.32639477363891256, -1.45405586112584, 0.5104603413606108, -0.6283556049853254, 0.35921840490046464, -1.1166717373759707, 1.2421363428579315], [0.47437350434528236, -0.5869506255304089, 1.1238033727822798, -0.636771573604883, -3.026453696487063, 1.4883306893450143, -0.003653258376682404], [0.7280219937828689, 1.0020700777947353, 0.30805432908984814, 0.5375366375652787, 1.6339651026692255, 0.28349556976234075, -1.3661378222603735], [-0.47727311717556536, 0.705476558805571, 0.5746190777222537, -1.3014789433223233, 0.7143543092835912, 1.0409966093914604, 0.4094902213915846], [-2.2767220978610694, 0.9688804605077019, 0.10016242214736573, -0.7609963642571461, 0.4212860697727443, -0.3003030394219786, 0.6435877178031163], [-0.3250341939699786, 0.7092636825352702, 0.5399773051284981, -2.1248173334464777, -1.383875775568984, 0.9928225823287155, 0.28369956445320926], [-0.5558741449106376, -0.6305691341606576, -0.13876290299640007, 0.006736011854435694, 0.6088391644377782, 0.12456557036992669, 0.09947937259705415]]



X = [[0.2586032225236904, 2.3226677848284996, -1.1589130729373596, -0.4357209676819266, 0.052754811988345224, 0.8448715800750733, 0.39341117857741253], [-1.2550683058904484, -0.10053464897649816, 1.7276939386644532, -0.17328709578066634, -0.5331010165652601, -0.3170499629743522, -0.420302840521378], [1.0919556903442502, 1.2883675461608641, -0.10645957552058809, -1.729904929592407, 0.4241332953480258, -0.019631228134280313, 1.633375224055798], [0.10543780027039822, -2.2967021747943446, 0.9425761311310806, -0.7454839559150747, -2.3605218721135652, 0.004296903863998751, -1.2609045529055976], [0.15013356541202794, 0.5860983693719376, -1.9373504235634, -2.0099031117499333, -1.5400965715572874, 0.9645025346585079, -0.045620529698997145], [-0.03930907700140845, 0.46017041224607474, 0.6341533376590722, -1.465103036196576, -0.6499659758277615, -1.3342126990517587, 0.8428630719753277], [0.12313523681559195, -1.4869308968840365, 0.5434141613283214, -0.7018534553119483, 0.184663522576039, 1.3069313771585263, -1.0681241303761622], [-1.4632702169503065, -0.8769567241405958, 0.37327049611503943, 0.21421971334624504, 0.31154000646167723, 0.9902797699647375, -0.20740764640581033], [-1.3668242306327807, -1.2965384850900208, 1.7027748276886117, -0.79641296920449, 0.8546209097078022, 1.8021748857868376, -0.10751885543930538], [0.5498967061367501, 0.23097979875875618, 0.08253894711672319, -0.2002160347190243, 0.05194836884380194, 0.8530292123937813, 1.5544219985283543]]
distance_threshold = 2.14795569675713

# some other dataset that has the same size as X, same point dimension for each element.
f_X = collect( randn(length(X[m])) for m in eachindex(X))

# single linkage.
distance_set, partition_set = SingleLinkagePartitions.runsinglelinkage(
    X,
    metricfunc;
    #early_stop_distance = 1.0,
    early_stop_distance = 5.023150248368374,
)

# this should be X.
Z0 = SingleLinkagePartitions.instantiatepartition(partition_set[begin], X)

# this should be the singleton partition.
Z_end = SingleLinkagePartitions.instantiatepartition(partition_set[end], X)


# Use single linkage to merge points.
#distance_threshold = 1.0
Y, status_flag = SingleLinkagePartitions.mergepoints(X, metricfunc; tol = distance_threshold)
@show status_flag

Y2, status_flag2, partitioned_set_sorted, h_set_sorted, chosen_ind = SingleLinkagePartitions.mergepointsfull(X, metricfunc; tol = distance_threshold)
Y3 = SingleLinkagePartitions.fuseparts(partitioned_set_sorted[chosen_ind], X)
println("Should be zero if merpointsfull() is working: ", norm(Y2-Y) + norm(Y3-Y) )
println()

# Test
# the elements of a partition is called a part. Some call it a cluster, if they call the set X the data set.
# the non-zero entries/parts in dists_X that are less than `distance_threshold` are combined into the same parts.
dists_X = SingleLinkagePartitions.getdistances(X, metricfunc)

# therefore, the non-zero entries of dists_Y should all be greater or equal to distance_threshold.
dists_Y = SingleLinkagePartitions.getdistances(Y, metricfunc)

println("if true, then Y = X, i.e. we have all singleton parts, i.e. X = Y. otherwise this should be false.")
@show SingleLinkagePartitions.checktoptriangle(dists_X, distance_threshold)
println()

println("Should be true: ")
@show SingleLinkagePartitions.checktoptriangle(dists_Y, distance_threshold)
println()

function checktoptriangle2(K::Matrix{T}, lb::T)::Bool where T

    S = K .> lb
    for i in axes(S,1)
        S[i,i] = true
    end

    return all(S)
end

@show checktoptriangle2(dists_Y, distance_threshold)


# mergepoints using X, but also merge the same entries for datasets contained in Zs.
Zs = Vector{Vector{Vector{T}}}(undef, 1)
Zs[begin] = f_X
Y2, Ys2, status_flag = SingleLinkagePartitions.mergepoints(
    X,
    Zs,
    metricfunc;
    tol = distance_threshold,
)
println("This should be true: ", status_flag)
println("This should be zero: ", norm(Y-Y2))

# If there is only one data set, such as f_X in this example, then we can avoid explicitly constructing Zs to contain f_X.
Y3, Yf_X, status_flag = SingleLinkagePartitions.mergepoints(
    X,
    f_X,
    metricfunc;
    tol = distance_threshold,
)
println("This should be true: ", status_flag)
println("This should be zero: ", norm(Y-Y3))
println("This should be zero: ", norm(Ys2[begin]-Yf_X))