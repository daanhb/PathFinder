function [z,w] = PathFinderQuad(a, b, phaseIn, freq, Npts, varargin)
%Construct weights and nodes to numerically evaluate an oscillatory
%integral.
%[z,w] = PathFinderQuad(a, b, G, k, N, infContour)
%returns weights w and nodes z for efficient evaluation of oscillatory
%integral of f(z)exp(i*k*g(z))dz from a to b, for analytic f & g.
%
%G is either the coefficients of a polynomial, in standard Matlab
%format: G(1)*X^N + ... + G(N)*X + phaseIn(N+1)
%
%a and b are either finite enpoints, or (in the case where the integral is an infinite contour)
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

    params = optionalExtras(freq,length(phaseIn)-1,varargin);

    if length(phaseIn)<=2 % if linear phase
        % contour can be computed instantly without approximation, reduce to this
        [z,w] = linear_phase_NSD(a,b,freq,phaseIn(1),phaseIn(2),Npts);
        if params.plot
            plotAll([], [], z, a, b, params.infContour, [], [], [], []);
        end
        return;
    end

    %get info about stationary points:
    [phase_handles, stationaryPoints, valleys] = getInfoFromPhase(phaseIn);

    % get r* parameter used for determining regions of no return
    params.r_star = get_r_star(phaseIn);

    % rotate inf valleys if required:
    [a,b,params] = Jordan_rotate(a,b,valleys,params);
    
    tic;
    %cover each stationary point:
    [covers, endPointIndices]...
            = getExteriorBalls(phase_handles{1},freq,stationaryPoints,params.infContour,a,b, ...
            params.numOscs, phaseIn, params.ball_clump_thresh,params.num_rays, params.interior_balls);
    if params.log.take
        params.log.add_to_log(sprintf("Ball construction:\t%fs",toc));
    end
    
    tic;
    %make the contours from each cover:
    contours = getContours(phaseIn, covers, valleys, endPointIndices, params);
    if params.log.take
        params.log.add_to_log(sprintf("Contour coarse construction:\t%fs",toc));
    end

    %choose the path from a to b
    tic;
    [quadIngredients, graph_data] = shortestInfinitePathV4(a,b,contours, covers, valleys, params);
    if params.log.take
        params.log.add_to_log(sprintf("Dijkstra shortest path:\t%fs",toc));
    end
    
    % filter out SD contours which are of much smaller value, or empty
    [quadIngredients, params.max_SP_integrand_val] = fliter_paths_v2(quadIngredients, phase_handles{1}, freq, params.contourStartThresh);

    if params.contourStartThresh==0
        params.max_SP_integrand_val = inf;
    end

    %get quadrature points
    tic;
    [z, w, HermiteInds] = makeQuadV4(quadIngredients, freq, Npts, phase_handles{1}, params);
    if params.log.take
        params.log.add_to_log(sprintf("Quadrature allocation time:\t%fs",toc));
    end

    %make a plot of what's happened, if requested
    if params.plot
        plotAll(covers, contours, z, a, b, params.infContour, stationaryPoints, HermiteInds, phaseIn, valleys);
    end

    if params.plot_graph
        finite_endpoints = [a b];
        finite_endpoints = finite_endpoints(~params.infContour)+1i*eps;
        plotGraph(graph_data, covers, finite_endpoints);
    end
end