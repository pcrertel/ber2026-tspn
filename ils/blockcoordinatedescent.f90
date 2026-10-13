! =====================================================================
!  module blockcoordinatedescent -> BCD, minpol, checkandupdate
!
!  Depende de: instance (tipos, evalf), geometry (polygon_contains_point_2d,
!              segments_int_2d)
! =====================================================================
module blockcoordinatedescent

    use geometry
    use instance

    implicit none

    contains

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine BCD(inst,count,tour,x,cost)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine must apply the Block Coordinate Descent Method (BCDM) 
        ! to optmize the points of x visited in a tour. It is assumed that 
        ! x(1:2,1:npol) is such that x(1:2,i) \in P_tour(i) for i = 1,...,npol,
        ! and that, ON ENTRY, cost holds the cost of the solution (tour,x).
        ! OPTIMIZATION: since each minpol call only changes the edges (kprev,k)
        ! and (k,knext), the cost is updated with the local delta gmin - oldloc
        ! instead of calling evalf. This removes one evalf and one full copy of
        ! x per cycle. As minpol returns the minimizer of the local sum of
        ! distances and the current point x(1:2,k) is feasible, gmin <= oldloc
        ! always holds and curcost is monotonically nonincreasing, so no
        ! rollback of x is needed.

        ! PARAMETERS
        real(kind=8), parameter :: macheps = epsilon( 1.0d0 ), macheps12 = sqrt( epsilon( 1.0d0 ) )

        ! LOCAL SCALARS
        integer :: k,kprev,knext,cic
        real(kind=8) :: gmin,oldloc,curcost,prevcost,testcost

        ! LOCAL ARRAYS
        real(kind=8) :: p(2),q(2)

        count%bcdmcalls = count%bcdmcalls+1
        prevcost = cost
        curcost = cost

        cic = 0

        do
            ! =======
            ! Iterate
            ! =======
            
            cic = cic + 1

            ! This loop runs through the polygons
            do k = 1, inst%npol
                ! If the polygon has only one vertex, there is nothing to optimize
                if ( inst%nvp(tour(k)) .gt. 1 ) then
                    ! Points before and after x(1:2,k) remain fixed
                    if ( k .eq. 1 ) then
                        kprev = inst%npol
                        knext = k+1
                    else if (k .eq. inst%npol) then
                        kprev = k-1
                        knext = 1
                    else
                        kprev = k-1
                        knext = k+1
                    end if

                    p(1:2) = x(1:2,kprev)
                    q(1:2) = x(1:2,knext)

                    ! Local cost of the two edges adjacent to x(1:2,k) before minpol
                    oldloc = norm2( x(1:2,k) - p(1:2) ) + norm2( x(1:2,k) - q(1:2) )

                    call minpol(inst,tour(k),p,q,x(1:2,k),gmin)

                    ! Only the edges (kprev,k) and (k,knext) changed
                    curcost = curcost + ( gmin - oldloc )
                end if
            end do

            ! =================
            ! Consistency check
            ! =================

            if ( debug ) then
                call evalf(inst%npol,x,testcost)     ! Objective function sum of distances
                if ( abs( testcost - curcost ) .gt. macheps12 * max( 1.0d0, abs(testcost) ) ) then       
                    write(99,*) 'There is something wrong!'
                    write(99,*) 'In BCD, incremental curcost = ',curcost,' evalf curcost = ',testcost
                end if
            end if

            ! ===============
            ! Should we stop?
            ! ===============
         
            ! Relative tolerance plus an absolute floor. The relative term alone
            ! cannot detect convergence to a zero-length tour: on instances whose
            ! neighbourhoods share a common point the cost decreases by a constant
            ! factor per cycle, so the relative decrease never falls below the
            ! tolerance and the incremental cost eventually drifts negative.
            if ( curcost .ge. prevcost - macheps12 * abs( prevcost ) - macheps ) then
                count%stopbcdf = count%stopbcdf+1
                count%bcdmcic = count%bcdmcic+cic
                cost = curcost
                return
            end if

            if ( cic .ge. count%maxbcdcic ) then
                count%stopbcdcic = count%stopbcdcic+1
                count%bcdmcic = count%bcdmcic+cic
                cost = curcost
                return
            end if

            prevcost = curcost
        end do
        
    end subroutine BCD

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine minpol(inst,pol,p,q,xmin,dmin)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst

        ! SCALAR ARGUMENTS
        integer, intent(in) :: pol
        real(kind=8), intent(out) :: dmin

        ! ARRAY ARGUMENTS
        real(kind=8), intent(in) :: p(2),q(2)
        real(kind=8), intent(inout) :: xmin(2)

        ! Obtains the point xmin belonging to the polygon pol that minimizes 
        ! the sum of Euclidean distances to the previous point p and next  
        ! point q in the tour. If the segment connecting p and q intersects  
        ! the polygon, the intersection point is used. Otherwise, the point 
        ! xmin is selected from the polygon's vertices or along its edges to 
        ! minimize the total distance to p and q.
        ! OPTIMIZATION: the precomputed bounding box of the polygon
        ! (inst%bbox) is used to skip the O(nvp) point-in-polygon tests and
        ! the O(nvp) segment intersection scan whenever they cannot succeed.

        ! PARAMETERS
        real(kind=8), parameter :: macheps = epsilon( 1.0d0 ), macheps12 = sqrt( macheps )
        
        ! LOCAL SCALARS
        logical :: midinpol
        integer :: i,iprev,inext,flagminpol,nv,nhit
        real(kind=8) :: dvert,lambda,h,hprev,alphap,alphaq,pprojn,qprojn,ro,omega,dpq,invdd,t,tref,bestdt,invpq2

        ! LOCAL ARRAYS
        real(kind=8) :: d(2),r(2),rbest(2),xmid(2)

        if ( debug ) then
            if ( pol .lt. 1 .or. pol .gt. inst%npol ) then
                write(*,*) 'There is something wrong!'
                write(*,*) 'pol = ',pol,' must be between 1 and npol = ',inst%npol
                stop
            end if
        end if

        nv = inst%nvp(pol)
        ! Degenerate neighborhood (a single point): that point is the only
        ! feasible one. Without this branch the scan over the edges would
        ! compute invdd = 1/|d|^2 with d = 0.
        if ( nv .eq. 1 ) then
            xmin(1:2) = inst%vcoor(1:2,1,pol)
            dmin = norm2( xmin(1:2) - p(1:2) ) + norm2( xmin(1:2) - q(1:2) )
            return
        end if


        ! OPTIMIZATION: norm2(p-q) was being computed up to three times
        dpq = norm2( p(1:2) - q(1:2) )
        
        ! When p and q coincide the segment [p,q] degenerates to a point and
        ! the scan for crossings cannot succeed; the midpoint test below
        ! handles the case and returns dmin = dpq, the value of the subproblem
        ! at x = p. (An earlier version set dmin = 0 here, which is not.)
        ! TIE-BREAK: every x in P \cap [p,q] attains the same optimal value
        ! dpq, so the choice among them is free. Writing x(t) = p + t (q-p),
        ! the distance to the nearer of p and q is dpq*min(t,1-t), maximal at
        ! t = 1/2. The midpoint is therefore tried FIRST: whenever it belongs
        ! to the polygon it is optimal and as far as possible from p and q,
        ! which avoids placing x on top of a neighbouring visit point -- a
        ! degenerate fixed point of the single-point block scheme that shows up
        ! when consecutive neighbourhoods overlap. It also covers the case in
        ! which p and q both belong to the polygon (p = q included), so no
        ! separate test for them is needed, and it replaces the O(nvp) scan for
        ! crossings by a single point-in-polygon test whenever it succeeds.
        xmid(1:2) = 0.5d0 * ( p(1:2) + q(1:2) )
        midinpol = .false.
        if ( xmid(1) .ge. inst%bbox(1,pol) .and. xmid(1) .le. inst%bbox(2,pol) .and. &
        xmid(2) .ge. inst%bbox(3,pol) .and. xmid(2) .le. inst%bbox(4,pol) ) then
            call polygon_contains_point_2d(nv,inst%vcoor(1:2,1:nv,pol),xmid(1:2),midinpol)
        end if
        if ( midinpol ) then
            xmin(1:2) = xmid(1:2)
            dmin = dpq
            return
        end if

        ! The midpoint is infeasible. If P \cap [p,q] is nonempty the segment
        ! crosses the boundary, and since t = 1/2 is infeasible the feasible t
        ! closest to 1/2 is attained at one of the crossings.
        if ( dpq .gt. macheps12 * max( 1.0d0, norm2( p(1:2) ) ) ) then
            if ( max( p(1), q(1) ) .ge. inst%bbox(1,pol) .and. min( p(1), q(1) ) .le. inst%bbox(2,pol) .and. &
            max( p(2), q(2) ) .ge. inst%bbox(3,pol) .and. min( p(2), q(2) ) .le. inst%bbox(4,pol) ) then
                tref = 0.5d0
                nhit = 0
                bestdt = huge( 1.0d0 )
                invpq2 = 1.0d0 / dot_product( q(1:2) - p(1:2), q(1:2) - p(1:2) )
                iprev = nv
                hprev = inst%vcoor(1,iprev,pol) * ( p(2) - q(2) ) + inst%vcoor(2,iprev,pol) * &
                ( q(1) - p(1) ) + p(1) * q(2) - p(2) * q(1)
                do i = 1,nv
                    h = inst%vcoor(1,i,pol) * ( p(2) - q(2) ) + inst%vcoor(2,i,pol) * ( q(1) - p(1) ) + p(1) * q(2) - p(2) * q(1)
                    if ( sign( 1.0d0, hprev ) .ne. sign( 1.0d0, h ) .or. ( hprev .eq. 0.0d0 .and. h .eq. 0.0d0 ) ) then
                        call segments_int_2d(inst%vcoor(1:2,iprev,pol),inst%vcoor(1:2,i,pol),p(1:2),q(1:2),flagminpol,r(1:2))
                        if ( flagminpol .eq. 1 ) then
                            nhit = nhit + 1
                            t = dot_product( r(1:2) - p(1:2), q(1:2) - p(1:2) ) * invpq2
                            t = max( 0.0d0, min( 1.0d0, t ) )
                            if ( abs( t - tref ) .lt. bestdt ) then
                                bestdt = abs( t - tref )
                                rbest(1:2) = r(1:2)
                            end if
                        end if
                    end if
                    hprev = h
                    iprev = i
                end do

                if ( nhit .gt. 0 ) then
                    xmin(1:2) = rbest(1:2)
                    dmin = dpq
                    return
                end if
            end if
        end if

        dmin = huge( 1.0d0 )

        ! This loop runs through the vertices of the polygon pol
        do i = 1, nv
            inext = mod( i, nv ) + 1
            dvert = norm2( inst%vcoor(1:2,i,pol) - p(1:2) ) + norm2( inst%vcoor(1:2,i,pol) - q(1:2) )
            if ( dvert .le. dmin ) then
                xmin(1:2) = inst%vcoor(1:2,i,pol)
                dmin = dvert
            end if

            d(1:2) = inst%vcoor(1:2,inext,pol) - inst%vcoor(1:2,i,pol)    

            ! OPTIMIZATION: dot_product(d,d) was being computed twice, with 
            ! one division for each of alphap and alphaq
            invdd = 1.0d0 / dot_product( d(1:2), d(1:2) )

            alphap = dot_product( p(1:2) - inst%vcoor(1:2,i,pol), d(1:2) ) * invdd
            alphaq = dot_product( q(1:2) - inst%vcoor(1:2,i,pol), d(1:2) ) * invdd
            
            pprojn = norm2( p(1:2) - inst%vcoor(1:2,i,pol) - alphap * d(1:2) )
            qprojn = norm2( q(1:2) - inst%vcoor(1:2,i,pol) - alphaq * d(1:2) )
            
            ro = alphaq * pprojn + alphap * qprojn
            omega = pprojn + qprojn

            if ( ro * omega .gt. 0.0d0 .and. abs(ro) .lt. abs(omega) ) then
                lambda =  ro / omega                   
                call checkandupdate(inst,i,pol,lambda,d,p,q,xmin,dmin)
            end if
        end do
        
    end subroutine minpol

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine checkandupdate(inst,i,polind,lambda,u,p,q,g,delta)
        
        implicit none
        
        ! SCALAR ARGUMENTS
        type(instance_type), intent(in) :: inst
        integer, intent(in) :: i,polind
        real(kind=8), intent(in) :: lambda
        real(kind=8), intent(inout) :: delta
        
        ! ARRAY ARGUMENTS
        real(kind=8), intent(in) :: u(2),p(2),q(2)
        real(kind=8), intent(inout) :: g(2)
        
        ! Evaluates candidate point and updates g if total distance to p and q is improved.
        
        ! LOCAL SCALARS
        real(kind=8) :: deltatemp
        
        ! LOCAL ARRAYS
        real(kind=8) :: v(2)
        
        v(1:2) = inst%vcoor(1:2,i,polind) + lambda * u(1:2)
        deltatemp = norm2( v(1:2) - p(1:2) ) + norm2( v(1:2) - q(1:2) )  
        if ( deltatemp .lt. delta ) then   
            g(1:2) = v(1:2)
            delta = deltatemp
        end if
    end subroutine checkandupdate

end module blockcoordinatedescent
