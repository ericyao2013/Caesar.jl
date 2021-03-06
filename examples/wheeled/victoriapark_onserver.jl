# Victoria Park using-server

using HDF5, JLD, Gadfly, Colors, Cairo
using KernelDensityEstimate, Distributions
using Caesar, IncrementalInference, RoME
# load all the model data
# d = odometry information
# f = laser scanner detections
# MM = multi-modal individual id references
# MMr = reworked to map to only one previous feature
# examplefolder, datafolder
function evalLikelihood(fg::FactorGraph, sym::Symbol, point::Vector{Float64})
  p = getVertKDE(fg, sym)
  Ndim(p) == length(point) ? nothing : error("point (dim=$(length(point))) must have same dimension as belief (dim=$(Ndim(p)))")
  evaluateDualTree(p, (point')')[1]
end

# Evaluate the likelihood of an Array{2} of points on the marginal belief of some variable
# note the dimensions must match
function evalLikelihood(fg::FactorGraph, sym::Symbol, points::Array{Float64,2})
  p = getVertKDE(fg, sym)
  Ndim(p) == size(points,1) ? nothing : error("points (dim=$(size(points,1))) must have same dimension as belief (dim=$(Ndim(p)))")
  evaluateDualTree(p, (points))
end



include(joinpath(Pkg.dir("Caesar"),"examples","wheeled","loadVicPrkData.jl"))


include(joinpath(Pkg.dir("Caesar"),"examples","database","blandauthremote.jl"))
user_config["session"] = "SESSVICPRK_DANIEL"
backend_config, user_config = standardcloudgraphsetup(addrdict=user_config)



# Start new session

Graphs.plot(fg.g)

fg = Caesar.initfg(sessionname=user_config["session"], cloudgraph=backend_config)

# deleteServerSession!(fg.cg, user_config["session"])

# init pose
prevn = initFactorGraph!(fg, init=d[1][1:3])
Podo=diagm([0.5;0.5;0.005])
N=100
lcmode=:unimodal
lsrNoise=diagm([0.1;1.0])


#build :# poses for the factorGraph
for idx=2:50
  prev, X, nextn = getLastPose2D(fg)
  vp, fp = addOdoFG!(fg, nextn, d[idx][1:3], Podo, N=N, labels=["POSE"])
  # add landmarks
  addLandmarksFactoGraph!(fg, f, idx, prevn, nextn, lcmode=lcmode, lsrNoise=lsrNoise, N=N, MM=MM)
  prevn = nextn
  # if (idx%10==0)
  #    Solve
  #    tree = prepBatchTree!(fg, drawpdf=true);
  #   @time inferOverTree!(fg,tree, N=100);
  # end
end


pl=drawPosesLandms(fg)
draw(PDF("before.pdf",20cm,20cm),pl)


# batchSolve(fg)
# on ssh terminal, run slamindb(iterations=1)

# fetch a local copy

fg = Caesar.initfg(sessionname=user_config["session"], cloudgraph=backend_config)
fullLocalGraphCopy!(fg)
pl1=drawPosesLandms(fg)

draw(PDF("after.pdf",20cm,20cm),pl1)



X,L = ls(fg)
d=0
t=[]
z=zeros(length(L)+1,length(L)+1)

j=1;
for l1 in L
  i=1
  for l2 in L
    b=getKDEMax(getVertKDE(fg, l1))
    c=evalLikelihood(fg, l2 , b)
    if ( c>0.002 && l1!=l2 )
      d+=1
      #Replace this with A delete and replace
      #what the hell should i do now
      addSoftEqualityPoint2D(fg, l1, l2 )

      push!(t,(l1,l2))
      z[i,j]=1
    elseif (l1==l2)
      z[i,j]=2
    end
    i+=1
  end
  j+=1
end
#run Server Code
fg = Caesar.initfg(sessionname=user_config["session"], cloudgraph=backend_config)
fullLocalGraphCopy!(fg)
pl2=drawPosesLandms(fg)
draw(PDF("daniel.pdf",20cm,20cm),pl2)


# Remove the new session from the server
deleteServerSession!(fg.cg, user_config["session"])
















#
