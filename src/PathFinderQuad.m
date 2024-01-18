function [z,w] = PathFinderQuad(a, b, phaseIn, freq, nPts, varargin)
%Construct weights and nodes to numerically evaluate an oscillatory
%integral.
%[z,w] = PathFinderQuad(a, b, G, k, N, infContour)
%returns weights w and nodes z for efficient evaluation of oscillatory
%integral of f(z)exp(i*k*g(z))dz from a to b, for analytic f & g.
%
%G is either the coefficients of a polynomial, in standard Matlab
%format: G(1)*X^N + ... + G(N)*X + phaseIn(N+1)
%
%a and b are either finite endpoints, or (in the case where the integral is an infinite contour)
%angles of valleys in the complex plane. The entries of (optional) two-dimensional
%flag infContour flag if the endpoint of the integral is infinite.
%
%k is the frequency parameter of the integral
%
%N is the number of points used per segment of the PathFinder routine.
%
%A large number of optional inputs are available. For more information,
%see
%<a href="matlab:web('www.github.com/AndrewGibbs/PathFinder','-browser')">github.com/AndrewGibbs/PathFinder</a>

    %% preprocessing
    % get first nonzero entry
    first_nonzero_index = find(phaseIn~=0,1,'first');
    phaseIn = phaseIn(first_nonzero_index:end);

    %% set parameters
    params = optionalExtras(freq,length(phaseIn)-1,varargin);

    %% special cases
    % check if standard quadrature is appropriate, if so, do that & terminate early
    if ((~params.infContour(1)) && (~params.infContour(2)) ...
        && checkEndpointWidth(a, b, phaseIn, freq, params.numOscs,...
            params.num_rays, params.interior_balls, params.imag_thresh, params.use_mex)) ||...
            (length(phaseIn)==1)

        [z, w_, dh_] = gaussQuadComplex(a,b,nPts);
        sgw = @(z) exp(1i*freq*polyval(phaseIn,z));
        w = w_.*dh_.*sgw(z);

       if params.plot
            plotAll([], [], z, a, b, params.infContour, [], [], [], []);
        end
       return
    end

    if length(phaseIn)<=2 % if linear phase
        % contour can be computed instantly without approximation, reduce to this
        [z,w] = linearPhaseNSD(a,b,freq,phaseIn(1),phaseIn(2),nPts);
        if params.plot
            plotAll([], [], z, a, b, params.infContour, [], [], [], []);
        end
        return;
    end

    %% main algorithm

    %get info about stationary points:
    [phaseHandle, stationaryPoints, valleys] = getInfoFromPhase(phaseIn);

    % get r* parameter used for determining regions of no return
    params.r_star = getRStar(phaseIn);

    % rotate inf valleys if required:
    [a,b,params] = JordanRotate(a,b,valleys,params);
    
    tic;
    %cover each stationary point:
    [covers, ~]...
            = getExteriorBalls(phaseHandle,freq,stationaryPoints,params.infContour,a,b, ...
            params.numOscs, phaseIn, params.ball_clump_thresh,params.num_rays, ...
            params.interior_balls, params.imag_thresh, params.use_mex);
    if params.log.take
        params.log.add_to_log(sprintf("Ball construction:\t%fs",toc));
    end
    
    tic;
    %make the contours from each cover:
    contours = getContours(phaseIn, covers, valleys, params);
    if params.log.take
        params.log.add_to_log(sprintf("Contour coarse construction:\t%fs",toc));
    end

    %choose the path from a to b
    tic;
    [quadIngredients, graph_data] = shortestInfinitePathV4(a,b,contours, covers, valleys, params);
    if params.log.take
        params.log.add_to_log(sprintf("Dijkstra shortest path:\t%fs",toc));
    end
    
    if params.contourStartThresh==0
        params.max_SP_integrand_val = inf;
    else
        % filter out SD contours which are of much smaller value, or empty
        [quadIngredients, params.max_SP_integrand_val] = fliterPaths(quadIngredients, phaseHandle, freq, params.contourStartThresh);
        if isinf(params.max_SP_integrand_val)
            error("Integral is infinite");
        elseif params.max_SP_integrand_val>1E16
            warning("Integral is greater than 1e16");
        elseif params.max_SP_integrand_val<1E-16
            warning("Integral is less than 1e-16");
        end
    end

    %get quadrature points
    tic;
    [z, w] = makeQuad(quadIngredients, freq, nPts, phaseHandle, params);
    if params.log.take
        params.log.add_to_log(sprintf("Quadrature allocation time:\t%fs",toc));
    end

    %make a plot of what's happened, if requested
    if params.plot
        plotAll(covers, contours, z, a, b, params.infContour, stationaryPoints, phaseIn, valleys);
    end

    if params.plot_graph
        finite_endpoints = [a b];
        finite_endpoints = finite_endpoints(~params.infContour)+1i*eps;
        plotGraph(graph_data, covers, finite_endpoints);
    end
end