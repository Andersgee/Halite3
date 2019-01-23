module df

#filter2d

function boxfilter(A::Array{Int64,2}, r::Int64)
    # preprocess
    h,w = size(A)
    c = [A[end-r:end,end-r:end] A[end-r:end,:] A[end-r:end,1:r]
         A[:,end-r:end]           A                A[:,1:r]
         A[1:r,end-r:end]         A[1:r,:]         A[1:r,1:r]]
    cumsum!(c, c, dims=1)
    cumsum!(c, c, dims=2)
    ul = view(c, 1:h, 1:w)
    ur = view(c, 1:h, 1 .+ 2r .+ (1:w))
    bl = view(c, 1 .+ 2r .+ (1:h), 1:w)
    br = view(c, 1 .+ 2r .+ (1:h), 1 .+ 2r .+ (1:w))
    return br - bl - ur + ul
end


function diamondfilter(A::Array{Int64,2}, r::Int64)
    h, w = size(A)

    function diagdiff(c, r)
        T = view(c, 1:h,              1 .+ r .+ (1:w))
        B = view(c, 2r .+ 2 .+ (1:h), 1 .+ r .+ (1:w))
        L = view(c, r .+ 1 .+ (1:h), 1:w)
        R = view(c, r .+ 1 .+ (1:h), 2r .+ 2 .+ (1:w))
        T + B - L - R
    end

    function diag1cumsum!(A::Array{Int64,2})
        for x in 2:size(A,2)
            for y in 2:size(A,1)
                A[y,x] += A[y-1, x-1]
            end
        end
    end

    function diag2cumsum!(A::Array{Int64,2})
        for x in size(A,2)-1:-1:1
            for y in 2:size(A,1)
                A[y,x] += A[y-1, x+1]
            end
        end
    end

    if r == 0 return A end

    c = [A[end-r-1:end, end-r:end]  A[end-r-1:end, :]  A[end-r-1:end, 1:r+1]
         A[:          , end-r:end]  A                  A[:          , 1:r+1]
         A[1:r+1      , end-r:end]  A[1:r+1      , :]  A[1:r+1      , 1:r+1]]
    diag1cumsum!(c)
    diag2cumsum!(c)

    return diagdiff(c, r) + diagdiff(view(c, 2:size(c,1)-1, 2:size(c,2)-1), r-1)
end

end