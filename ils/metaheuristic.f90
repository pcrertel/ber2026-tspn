! =====================================================================
!  module metaheuristic -> NN, Neighborhoods, Moves, VND, ILS
!
!  Depende de: instance (tipos, evalf, drand, dswap*, I/O),
!              blockcoordinatedescent (BCD, minpol)
!  ASSCT (assct.f) permanece um procedimento externo em F77.
! =====================================================================
module metaheuristic

    use instance
    use blockcoordinatedescent

    implicit none

    contains

    subroutine nn(inst,count,inipol,tour,x,cost)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        integer, intent(in) :: inipol
        real(kind=8), intent(out) :: cost

        ! ARRAY ARGUMENTS
        integer, intent(out) :: tour(inst%npol) 
        real(kind=8), intent(out) :: x(2,inst%npol)
        
        ! This routine must build an initial solution with the 
        ! Nearest Neighbor (NN) heuristic.
        
        ! LOCAL VARIABLES
        logical :: visited(inst%npol)             
        integer :: i,j,currentpol,nextpol  
        real(kind=8) :: mindist,tempdist

        count%hcalls = count%hcalls + 1 

        ! tour, x and cost are intent(out), so returning here would hand the
        ! caller three UNDEFINED arrays instead of a solution - and the ILS
        ! calls this routine in the middle of the search (the noimprov = 3
        ! restart), where it would go on perturbing garbage. Clamp to polygon 1
        ! and carry on: the starting polygon only decides which greedy tour is
        ! built, so any valid choice yields a valid solution.
        currentpol = inipol
        if ( currentpol .lt. 1 .or. currentpol .gt. inst%npol ) then
            write(0,*) 'WARNING: initial polygon ',inipol,' outside [1,...,', &
            inst%npol,'] - starting from polygon 1 instead - nn.'
            currentpol = 1
        end if

        cost = 0.0d0
        visited(1:inst%npol) = .false.

        ! Starting point (polygon)
        tour(1) = currentpol
        x(1:2,1) = inst%barycenters(1:2,currentpol)
        visited(currentpol) = .true.

        ! Find the Nearest Neighbor for the remaining m-1 polygons
        do i = 2, inst%npol
            mindist = huge( 1.0d0 ) ! start from a very large value
            nextpol = 0

            ! Search for the Nearest Neighbor
            do j = 1, inst%npol
                ! Checks whether the j-th polygon was visited
                if (.not. visited(j)) then

                    tempdist = norm2( inst%barycenters(1:2,currentpol) - inst%barycenters(1:2,j) )
                    
                    if ( tempdist .lt. mindist ) then
                        mindist = tempdist
                        nextpol = j
                    end if
                end if
            end do

            ! Updates the tour and visited polygons
            if ( nextpol .ne. 0 ) then
                tour(i) = nextpol
                x(1:2,i) = inst%barycenters(1:2,nextpol)
                visited(nextpol) = .true.
                currentpol = nextpol
                cost = cost + mindist
            else
                ! Safety, in case we cannot find a neighbor (should not occur if npol >= 2)
                exit 
            end if
        end do

        cost = cost + norm2( x(1:2,1) - x(1:2,inst%npol) )
        call BCD(inst,count,tour,x,cost)

    end subroutine nn

    ! *****************************************************************
    ! *****************************************************************

    subroutine SwapN(inst,count,tour,x,cost,alcallbcd,bestimp)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        logical, intent(in) :: alcallbcd
        ! Improvement strategy of this neighborhood:
        !   .false. = first improvement (stop at the first improving move)
        !   .true.  = best improvement  (scan the whole neighborhood and
        !             apply the cheapest improving move found)
        ! The candidate-list pruning is the SAME in both: for the swap and
        ! the 2-opt it is exact, so the best move of the pruned neighborhood
        ! is the best move of the full one.
        logical, intent(in) :: bestimp
        real(kind=8), intent(inout) :: cost

        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol)

        ! This routine applies the swap heuristic, with first or best
        ! improvement according to bestimp, + BCD in each new permutation if
        ! alcallbcd = true, or BCD only in the final permutation, otherwise.
        !
        ! CANDIDATE LISTS. Swapping positions i and j removes 4 edges and
        ! inserts 4. Pairing each removed edge with the inserted one that takes
        ! its place, the gain splits into four brackets:
        !   [d(i-1,i) - d(i-1,j)] + [d(i,i+1) - d(j,i+1)]
        ! + [d(j-1,j) - d(j-1,i)] + [d(j,j+1) - d(i,j+1)]
        ! If the total gain is positive, at least one bracket is positive, and
        ! each bracket is a fixed-radius condition:
        !   scan A: d(i-1,j) < d(i-1,i)  =>  j among the candidates of tour(i-1)
        !   scan B: d(j,i+1) < d(i,i+1)  =>  j among the candidates of tour(i+1)
        ! The last two brackets are these same two with i and j exchanged, and
        ! the swap is symmetric, so sweeping every position as i covers them.
        ! The scan is therefore EXACT: it never discards an improving swap. The
        ! only approximation is the truncation of the lists at inst%ncand.
        ! Cost drops from O(N^2) to O(N*K).

        ! LOCAL SCALARS
        logical :: stopswap
        integer :: i,j,m,p,a,b,pm,pp,scan
        real(kind=8) :: swapcost,bestcost,rad

        ! LOCAL ARRAYS
        integer :: swaptour(inst%npol),bestour(inst%npol),pos(inst%npol)
        real(kind=8) :: swaptsol(2,inst%npol),bestsol(2,inst%npol)

        count%swapcall = count%swapcall + 1

        bestour = tour
        bestsol = x
        bestcost = cost

        do i = 1, inst%npol
            pos(tour(i)) = i
        end do

        stopswap = .false.

        do p = 1, inst%npol
            if ( stopswap ) exit

            pm = merge(inst%npol, p-1, p .eq. 1)
            pp = merge(1, p+1, p .eq. inst%npol)

            do scan = 1, 2
                if ( stopswap ) exit

                if ( scan .eq. 1 ) then
                    ! Scan A: the new edge (i-1,j) must beat the removed (i-1,i)
                    j = pm
                    rad = norm2( x(1:2,pm) - x(1:2,p) )
                else
                    ! Scan B: the new edge (j,i+1) must beat the removed (i,i+1)
                    j = pp
                    rad = norm2( x(1:2,p) - x(1:2,pp) )
                end if

                do m = 1, inst%ncand
                    ! The list is ordered: no later candidate can be closer
                    if ( inst%canddist(m,tour(j)) .ge. rad ) exit

                    b = pos(inst%cand(m,tour(j)))
                    a = min(p,b)
                    b = max(p,b)

                    ! Same pairs as the exhaustive scan: j >= i+2
                    if ( b .lt. a+2 ) cycle

                    call SwapMove(inst%npol,tour,swaptour,x,swaptsol,cost,swapcost,a,b)
                    if ( alcallbcd ) then
                        call BCD(inst,count,swaptour,swaptsol,swapcost)
                    end if
                    if ( swapcost .lt. bestcost ) then
                        bestcost = swapcost
                        bestour = swaptour
                        bestsol = swaptsol
                        if ( .not. bestimp ) then
                            stopswap = .true.
                            exit
                        end if
                    end if
                end do
            end do
        end do

        if ( .not.(alcallbcd) ) then
            call BCD(inst,count,bestour,bestsol,bestcost)
        end if

        tour = bestour
        x = bestsol
        cost = bestcost

    end subroutine SwapN

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine DoubleBridgeN(inst,count,tour,x,cost)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 
        
        ! This routine must return the best Double-Bridge neighbor
        ! (based on the paper F. Glover. “Finding a best traveling 
        ! salesman 4-opt move in the same time as a best 2-opt move”. 
        ! Journal of Heuristics 2.2 (1996), pgs. 169–179) + BCD only 
        ! in the final permutation.

        ! LOCAL SCALARS
        integer :: i,j,i1,j1,i2,j2,typpe
        real(kind=8), parameter :: infty = huge( 1.0d0 ), macheps12 = sqrt( epsilon( 1.0d0 ) )
        real(kind=8) :: best_t,costc,costd,newcost,testcost

        ! LOCAL ARRAYS
        integer :: pred_t1(2),pred_t2(2),newtour(inst%npol),pred_reach_d(inst%npol),&
        pred_reach_c(inst%npol),pred_cross_d(inst%npol,2),pred_cross_c(inst%npol,2)
        real(kind=8) :: newx(2,inst%npol),best_reach_d(inst%npol),best_reach_c(inst%npol),&
        best_cross_d(inst%npol),best_cross_c(inst%npol),edgelen(inst%npol)

        count%dbcall = count%dbcall + 1

        ! OPTIMIZATION: precomputes the length of the current tour edges.
        ! Inside cost_d and cost_c each of these lengths was being recomputed
        ! with norm2 for every pair (i,j) of the O(npol^2) loop below.
        do i = 1, inst%npol-1
            edgelen(i) = norm2( x(1:2,i) - x(1:2,i+1) )
        end do
        edgelen(inst%npol) = norm2( x(1:2,inst%npol) - x(1:2,1) )

        pred_t1(1:2) = -1
        pred_t2(1:2) = -1

        ! ==========================================
        ! Step 1 (Initialization)
        ! ==========================================
        best_t = infty
        do j = 3, inst%npol-1
            ! Initialize D (Disconnecting) paths
            best_reach_d(j) = cost_d(inst%npol,1,j,x,edgelen)
            pred_reach_d(j) = 1
            
            ! Initialize C (Connecting) paths
            best_reach_c(j) = cost_c(inst%npol,1,j,x,edgelen)
            pred_reach_c(j) = 1

            ! Execute Simple Terminal Node Update for i=1
            ! OPTIMIZATION: reuses best_reach_c(j) instead of calling cost_c again
            costc = best_reach_c(j)
            if ( costc .lt. best_t ) then
                best_t = costc
                pred_t2 = (/ 1, j /)
                typpe = 0
            end if 
        end do

        ! ==========================================
        ! Step 2 (Main Step)
        ! ==========================================
        do i = 2, inst%npol-2
            ! Shift the cross arrays forward safely
            best_cross_d(i+1) = best_reach_d(i+1)
            pred_cross_d(i+1,1:2) = (/ pred_reach_d(i+1), i+1 /)
            
            best_cross_c(i+1) = best_reach_c(i+1)
            pred_cross_c(i+1,1:2) = (/ pred_reach_c(i+1), i+1 /)

            do j = i+2, inst%npol
                ! OPTIMIZATION: cost_d and cost_c are computed only once per
                ! pair (i,j). They were being called twice (Reach and Terminal).
                costd = cost_d(inst%npol,i,j,x,edgelen)
                costc = cost_c(inst%npol,i,j,x,edgelen)

                if ( j .le. inst%npol-1 ) then
                    ! --- Best Cross Updates ---
                    if ( best_reach_d(j) .lt. best_cross_d(j-1) ) then
                        best_cross_d(j) = best_reach_d(j)
                        pred_cross_d(j,1:2) = (/ pred_reach_d(j), j /)
                    else
                        best_cross_d(j) = best_cross_d(j-1)
                        pred_cross_d(j,1:2) = pred_cross_d(j-1,1:2)
                    end if

                    if ( best_reach_c(j) .lt. best_cross_c(j-1) ) then
                        best_cross_c(j) = best_reach_c(j)
                        pred_cross_c(j,1:2) = (/ pred_reach_c(j), j /)
                    else
                        best_cross_c(j) = best_cross_c(j-1)
                        pred_cross_c(j,1:2) = pred_cross_c(j-1,1:2)
                    end if

                    ! --- Best Reach Updates ---
                    if ( costd .lt. best_reach_d(j) ) then
                        best_reach_d(j) = costd
                        pred_reach_d(j) = i
                    end if
                    
                    if ( costc .lt. best_reach_c(j) ) then
                        best_reach_c(j) = costc
                        pred_reach_c(j) = i
                    end if
                end if

                ! --- Best Terminal Node Updates ---

                ! TYPE 1 MOVE: Double Bridge (d + d)
                if ( costd + best_cross_d(j-1) .lt. best_t ) then
                    best_t = costd + best_cross_d(j-1)
                    pred_t1 = pred_cross_d(j-1,1:2)
                    pred_t2 = (/ i, j /)
                    typpe = 1
                end if

                ! TYPE 2a MOVE: Twisted Bridge (d + c)
                if ( costd + best_cross_c(j-1) .lt. best_t ) then
                    best_t = costd + best_cross_c(j-1)
                    pred_t1 = pred_cross_c(j-1,1:2)
                    pred_t2 = (/ i, j /)
                    typpe = 2
                end if

                ! TYPE 2b MOVE: Twisted Bridge (c + d)
                if ( costc + best_cross_d(j-1) .lt. best_t ) then
                    best_t = costc + best_cross_d(j-1)
                    pred_t1 = pred_cross_d(j-1,1:2)
                    pred_t2 = (/ i, j /)
                    typpe = 3
                end if

                ! TYPE 0 MOVE: Simple 2-opt (c)
                if ( costc .lt. best_t ) then
                    best_t = costc
                    pred_t2 = (/ i, j /)
                    typpe = 0
                end if
            end do
        end do

        ! ==========================================
        ! Step 3 (Solution Recovery)
        ! ==========================================
        ! If best_t >= 0, no improvement was found. Exit early!
        if ( best_t .ge. -1.0d-8 ) return

        ! Extract Indices
        if ( typpe .ne. 0 ) then
            i1 = pred_t1(1)
            j1 = pred_t1(2)
        end if
        i2 = pred_t2(1)
        j2 = pred_t2(2)

        ! Reconstruct Physical Arrays
        if ( typpe .eq. 0 ) then
            call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,i2,j2)
        else if ( typpe .eq. 1 ) then
            call DoubleBridgeMove(inst%npol,tour,newtour,x,newx,cost,newcost,i1,i2,j1,j2)
        else if ( typpe .eq. 2 .or. typpe .eq. 3 ) then
            call Type2Move(inst%npol,tour,newtour,x,newx,cost,newcost,i1,i2,j1,j2,typpe)
        end if

        if ( debug ) then
            ! The delta computed inside the move must match both evalf and
            ! the value best_t computed by the Glover algorithm
            call evalf(inst%npol,newx,testcost)
            if ( abs( testcost - newcost ) .gt. macheps12 * max( 1.0d0, abs(testcost) ) .or. &
            abs( ( cost + best_t ) - newcost ) .gt. macheps12 * max( 1.0d0, abs(newcost) ) ) then
                write(99,*) 'There is something wrong!'
                write(99,*) 'In DoubleBridgeN, newcost = ',newcost,' evalf = ',testcost,&
                ' cost + best_t = ',cost + best_t,' typpe = ',typpe
            end if
        end if

        ! Calculate True Continuous Cost via BCD
        call BCD(inst,count,newtour,newx,newcost)

        ! Apply Move
        if ( newcost .lt. cost ) then
            tour = newtour
            x = newx
            cost = newcost
        end if
    end subroutine DoubleBridgeN

    ! *****************************************************************
    ! *****************************************************************

    subroutine G2opt(inst,count,tour,x,cost,alcallbcd,bestimp)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        logical, intent(in) :: alcallbcd
        ! Improvement strategy of this neighborhood:
        !   .false. = first improvement (stop at the first improving move)
        !   .true.  = best improvement  (scan the whole neighborhood and
        !             apply the cheapest improving move found)
        ! The candidate-list pruning is the SAME in both: for the swap and
        ! the 2-opt it is exact, so the best move of the pruned neighborhood
        ! is the best move of the full one.
        logical, intent(in) :: bestimp
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine applies the generalized 2-opt heuristic, with first or
        ! best improvement according to bestimp, + BCD in each new permutation
        ! if alcallbcd = true, or BCD only in the final permutation, otherwise.
        !
        ! CANDIDATE LISTS (Section 3.1 of Schmidt & Irnich, 2022). Instead of
        ! scanning the O(npol^2) pairs (i,j) exhaustively, the scan follows
        ! the gain criterion of Lin & Kernighan: a 2-opt move that removes the
        ! edges (a,a+1) and (b,b+1) and inserts (a,b) and (a+1,b+1) can only
        ! improve if
        !       d(a,b) < d(a,a+1)     OR     d(a+1,b+1) < d(b,b+1),
        ! since otherwise the sum of the inserted edges is already >= the sum
        ! of the removed ones. So it is enough to look, for each position, at
        ! the polygons that are CLOSER than the tour edge being removed. Those
        ! are read from inst%cand, ordered by inst%canddist, which is a LOWER
        ! BOUND on the length of the new edge: as soon as canddist >= the
        ! removed edge, every remaining candidate is provably useless and the
        ! scan stops.
        !   Scan A covers the first case (the new edge (a,b) leaves position a).
        !   Scan B covers the second one (the new edge (a+1,b+1) arrives at
        !   position b+1, so the removed edge is the predecessor of b+1).
        ! The radius test is EXACT (it never discards an improving move). The
        ! only approximation is the truncation of the list at inst%ncand: with
        ! ncand >= npol-1 the scan is provably complete and equivalent to the
        ! exhaustive one.

        ! LOCAL SCALARS
        logical :: stop2opt
        integer :: i,j,m,a,b,ii,inext,iprev,jprev,polii
        real(kind=8) :: twoptcost,bestcost,ledge

        ! LOCAL ARRAYS
        integer :: twoptour(inst%npol),bestour(inst%npol),pos(inst%npol)
        real(kind=8) :: twoptsol(2,inst%npol),bestsol(2,inst%npol)

        count%twoptcall = count%twoptcall + 1

        bestour = tour
        bestsol = x
        bestcost = cost

        ! pos(p) = position occupied by polygon p in the current tour
        do i = 1, inst%npol
            pos(tour(i)) = i
        end do

        stop2opt = .false.
        ii = 1
        do while ( ii .le. inst%npol .and. .not.(stop2opt) )

            polii = tour(ii)

            ! ---------------------------------------------------------
            ! Scan A: the new edge leaves position ii, so the removed 
            ! edge is (ii,ii+1) and the move is (a,b) = (ii,j)
            ! ---------------------------------------------------------
            inext = merge(1, ii+1, ii .eq. inst%npol)
            ledge = norm2( x(1:2,ii) - x(1:2,inext) )

            m = 1
            do while ( m .le. inst%ncand .and. .not.(stop2opt) )
                ! The list is ordered: from here on no candidate can be closer
                if ( inst%canddist(m,polii) .ge. ledge ) exit

                j = pos(inst%cand(m,polii))
                a = min(ii,j)
                b = max(ii,j)

                if ( b .ge. a+2 .and. .not.( a .eq. 1 .and. b .eq. inst%npol ) ) then
                    call TwoOptMove(inst%npol,tour,twoptour,x,twoptsol,cost,twoptcost,a,b)
                    if ( alcallbcd ) then
                        call BCD(inst,count,twoptour,twoptsol,twoptcost)
                    end if
                    if ( twoptcost .lt. bestcost ) then
                        bestcost = twoptcost
                        bestour = twoptour
                        bestsol = twoptsol
                        if ( .not. bestimp ) stop2opt = .true.
                    end if
                end if
                m = m + 1
            end do

            ! ---------------------------------------------------------
            ! Scan B: the new edge arrives at position ii, so the 
            ! removed edge is (ii-1,ii) and the move is 
            ! (a,b) = (j-1,ii-1)
            ! ---------------------------------------------------------
            if ( .not.(stop2opt) ) then
                iprev = merge(inst%npol, ii-1, ii .eq. 1)
                ledge = norm2( x(1:2,iprev) - x(1:2,ii) )

                m = 1
                do while ( m .le. inst%ncand .and. .not.(stop2opt) )
                    if ( inst%canddist(m,polii) .ge. ledge ) exit

                    j = pos(inst%cand(m,polii))
                    jprev = merge(inst%npol, j-1, j .eq. 1)
                    a = min(iprev,jprev)
                    b = max(iprev,jprev)

                    if ( b .ge. a+2 .and. .not.( a .eq. 1 .and. b .eq. inst%npol ) ) then
                        call TwoOptMove(inst%npol,tour,twoptour,x,twoptsol,cost,twoptcost,a,b)
                        if ( alcallbcd ) then
                            call BCD(inst,count,twoptour,twoptsol,twoptcost)
                        end if
                        if ( twoptcost .lt. bestcost ) then
                            bestcost = twoptcost
                            bestour = twoptour
                            bestsol = twoptsol
                            if ( .not. bestimp ) stop2opt = .true.
                        end if
                    end if
                    m = m + 1
                end do
            end if

            ii = ii + 1
        end do

        if ( .not.(alcallbcd) ) then
            call BCD(inst,count,bestour,bestsol,bestcost)
        end if

        tour = bestour
        x = bestsol
        cost = bestcost
    end subroutine G2opt

    ! *****************************************************************
    ! *****************************************************************

    subroutine G3opt(inst,count,tour,x,cost,alcallbcd,bestimp)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        logical, intent(in) :: alcallbcd
        ! Improvement strategy of this neighborhood:
        !   .false. = first improvement (stop at the first improving move)
        !   .true.  = best improvement  (scan the whole neighborhood and
        !             apply the cheapest improving move found)
        ! The candidate-list pruning is the SAME in both: for the swap and
        ! the 2-opt it is exact, so the best move of the pruned neighborhood
        ! is the best move of the full one.
        logical, intent(in) :: bestimp
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine applies the generalized 3-opt heuristic, with first or
        ! best improvement according to bestimp, + BCD in each new permutation
        ! if alcallbcd = true, or BCD only in the final permutation, otherwise.
        !
        ! SEQUENTIAL SEARCH (Lin-Kernighan gain criterion, Section 3.1 of
        ! Schmidt & Irnich 2022). Instead of enumerating i < j < k, the scan
        ! builds an alternating chain
        !     t1 -R- t2 -A- t3 -R- t4 -A- t5 -R- t6 -A- t1
        ! where R are removed tour edges and A are added edges, requiring the
        ! partial gains g1 and g2 to stay POSITIVE. Added edges are taken from
        ! the candidate lists (inst%cand, ordered by inst%canddist, which is a
        ! LOWER BOUND on the edge length), so each scan stops as soon as
        ! canddist >= the current radius: from there on no candidate can keep
        ! the partial gain positive.
        !
        ! WHY THE CHAIN, AND NOT AN ANCHOR AT (i,i+1). The sequential search
        ! theorem guarantees that every improving move has SOME removed edge
        ! and SOME direction from which all partial gains are positive - not
        ! that a fixed anchor works. Anchoring every chain at (i,i+1) with
        ! t2 = i+1 covers only 1 of the 6 possibilities and provably loses
        ! moves. Here t1 sweeps every position and both directions are tried
        ! at each step (dir = +1 successor, -1 predecessor), so all anchors
        ! are covered by construction.
        !
        ! Each chain is then mapped back to (i,j,k,mtype): the three removed
        ! edges give the break positions i < j < k, and the set of added edges
        ! identifies which of the four pure 3-opt reconnections it is:
        !     M1 = A B' C' D    M2 = A C B' D    M3 = A C' B D    M4 = A C B D
        ! Chains whose added edges match none of them are 2-opt-like moves
        ! (already covered by G2opt) and are discarded.
        !
        ! The radius test is EXACT: it never discards an improving move. The
        ! only approximation is the truncation of the lists at inst%ncand.

        ! PARAMETERS
        real(kind=8), parameter :: tol = 1.0d-12

        ! LOCAL SCALARS
        logical :: stop3opt
        integer :: i,j,k,ip,jp,kp,m1,m2,mm,mtype,itmp
        integer :: t1,t2,t3,t4,t5,t6,dd1,dd2,dd3,dir1,dir2,dir3
        integer :: b1,b2,b3
        real(kind=8) :: bestcost,hatcost,cost1,cost2,cost3,cost4,newcost
        real(kind=8) :: dd,g1,g2,gain

        ! LOCAL ARRAYS
        integer :: newtour(inst%npol),bestour(inst%npol),hatour(inst%npol), &
        tour1(inst%npol),tour2(inst%npol),tour3(inst%npol),tour4(inst%npol), &
        pos(inst%npol),addp(2,3),cnd(2,3)
        real(kind=8) :: bestsol(2,inst%npol),hatsol(2,inst%npol),sol1(2,inst%npol), &
        sol2(2,inst%npol),sol3(2,inst%npol),sol4(2,inst%npol),newx(2,inst%npol)

        count%treeoptcall = count%treeoptcall + 1

        bestour = tour
        bestsol = x
        bestcost = cost
        stop3opt = .false.

        ! Inverse position array: pos(p) = position of polygon p in the tour
        do i = 1, inst%npol
            pos(tour(i)) = i
        end do

        ! =====================================================================
        ! DEGENERATE CASES (j == i+1 or k == j+1)
        ! Empty segments that degenerate into relocations/insertions. They cost
        ! O(N^2), so they are enumerated without candidate lists.
        ! =====================================================================
        deg_outer1: do i = 1, inst%npol-4
            j = i + 1
            do k = j + 1, inst%npol - 1
                call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,j,k)
                call TwoOptMove(inst%npol,newtour,hatour,newx,hatsol,newcost,hatcost,i,k)
                if ( alcallbcd ) call BCD(inst,count,hatour,hatsol,hatcost)
                if ( hatcost .lt. bestcost ) then
                    bestcost = hatcost
                    bestour = hatour
                    bestsol = hatsol
                    if ( .not. bestimp ) then
                        stop3opt = .true.
                        exit deg_outer1
                    end if
                end if
            end do
        end do deg_outer1

        if ( .not. stop3opt ) then
            deg_outer2: do i = 1, inst%npol-4
                do j = i + 2, inst%npol - 2
                    k = j + 1
                    call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,i,j)
                    call TwoOptMove(inst%npol,newtour,hatour,newx,hatsol,newcost,hatcost,i,k)
                    if ( alcallbcd ) call BCD(inst,count,hatour,hatsol,hatcost)
                    if ( hatcost .lt. bestcost ) then
                        bestcost = hatcost
                        bestour = hatour
                        bestsol = hatsol
                        if ( .not. bestimp ) then
                            stop3opt = .true.
                            exit deg_outer2
                        end if
                    end if
                end do
            end do deg_outer2
        end if

        ! =====================================================================
        ! SEQUENTIAL SEARCH over the chain t1 ... t6
        ! =====================================================================
        if ( .not. stop3opt ) then

            seq_outer: do t1 = 1, inst%npol
                do dd1 = 1, 2
                    dir1 = merge(1,-1,dd1 .eq. 1)
                    t2 = nbpos(t1,dir1)
                    dd = edge(t1,t2)

                    ! --- 1st scan: t3 near t2, radius d(t1,t2) ---
                    do m1 = 1, inst%ncand
                        if ( inst%canddist(m1,tour(t2)) .ge. dd ) exit
                        t3 = pos(inst%cand(m1,tour(t2)))
                        g1 = dd - edge(t2,t3)
                        if ( g1 .le. tol ) cycle

                        do dd2 = 1, 2
                            dir2 = merge(1,-1,dd2 .eq. 1)
                            t4 = nbpos(t3,dir2)

                            ! --- 2nd scan: t5 near t4, radius d(t3,t4) + g1 ---
                            do m2 = 1, inst%ncand
                                if ( inst%canddist(m2,tour(t4)) .ge. edge(t3,t4) + g1 ) exit
                                t5 = pos(inst%cand(m2,tour(t4)))
                                g2 = g1 + edge(t3,t4) - edge(t4,t5)
                                if ( g2 .le. tol ) cycle

                                do dd3 = 1, 2
                                    dir3 = merge(1,-1,dd3 .eq. 1)
                                    t6 = nbpos(t5,dir3)

                                    ! Total gain of closing the chain at t1
                                    gain = g2 + edge(t5,t6) - edge(t6,t1)
                                    if ( gain .le. 1.0d-9 ) cycle

                                    ! --- map the chain back to (i,j,k) ---
                                    b1 = brkpos(t1,dir1)
                                    b2 = brkpos(t3,dir2)
                                    b3 = brkpos(t5,dir3)
                                    i = b1; j = b2; k = b3
                                    if ( i .gt. j ) then
                                        itmp = i; i = j; j = itmp
                                    end if
                                    if ( j .gt. k ) then
                                        itmp = j; j = k; k = itmp
                                    end if
                                    if ( i .gt. j ) then
                                        itmp = i; i = j; j = itmp
                                    end if

                                    ! Same index range as the exhaustive version;
                                    ! degenerate cases are handled above
                                    if ( k .gt. inst%npol-1 ) cycle
                                    if ( j .lt. i+2 .or. k .lt. j+2 ) cycle

                                    ip = i + 1
                                    jp = j + 1
                                    kp = k + 1

                                    ! --- which reconnection is it? ---
                                    addp(1,1) = t2; addp(2,1) = t3
                                    addp(1,2) = t4; addp(2,2) = t5
                                    addp(1,3) = t6; addp(2,3) = t1

                                    mtype = 0
                                    do mm = 1, 4
                                        if ( mm .eq. 1 ) then
                                            cnd(1,1)=i;  cnd(2,1)=j
                                            cnd(1,2)=ip; cnd(2,2)=k
                                            cnd(1,3)=jp; cnd(2,3)=kp
                                        else if ( mm .eq. 2 ) then
                                            cnd(1,1)=i;  cnd(2,1)=jp
                                            cnd(1,2)=k;  cnd(2,2)=j
                                            cnd(1,3)=ip; cnd(2,3)=kp
                                        else if ( mm .eq. 3 ) then
                                            cnd(1,1)=i;  cnd(2,1)=k
                                            cnd(1,2)=jp; cnd(2,2)=ip
                                            cnd(1,3)=j;  cnd(2,3)=kp
                                        else
                                            cnd(1,1)=i;  cnd(2,1)=jp
                                            cnd(1,2)=k;  cnd(2,2)=ip
                                            cnd(1,3)=j;  cnd(2,3)=kp
                                        end if
                                        if ( pairin(addp(1,1),addp(2,1),cnd) .and. &
                                             pairin(addp(1,2),addp(2,2),cnd) .and. &
                                             pairin(addp(1,3),addp(2,3),cnd) ) then
                                            mtype = mm
                                            exit
                                        end if
                                    end do

                                    ! Not one of the four pure 3-opt moves
                                    ! (2-opt-like: already covered by G2opt)
                                    if ( mtype .eq. 0 ) cycle

                                    ! --- apply ---
                                    if ( mtype .eq. 1 ) then
                                        ! M1 = A B' C' D
                                        call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,i,j)
                                        call TwoOptMove(inst%npol,newtour,tour1,newx,sol1,newcost,cost1,j,k)
                                        if ( alcallbcd ) call BCD(inst,count,tour1,sol1,cost1)
                                        if ( cost1 .lt. bestcost ) then
                                            bestcost = cost1; bestour = tour1; bestsol = sol1
                                            if ( .not. bestimp ) then
                                                stop3opt = .true.
                                                exit seq_outer
                                            end if
                                        end if
                                    else if ( mtype .eq. 2 ) then
                                        ! M2 = A C B' D
                                        call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,j,k)
                                        call TwoOptMove(inst%npol,newtour,tour2,newx,sol2,newcost,cost2,i,k)
                                        if ( alcallbcd ) call BCD(inst,count,tour2,sol2,cost2)
                                        if ( cost2 .lt. bestcost ) then
                                            bestcost = cost2; bestour = tour2; bestsol = sol2
                                            if ( .not. bestimp ) then
                                                stop3opt = .true.
                                                exit seq_outer
                                            end if
                                        end if
                                    else if ( mtype .eq. 3 ) then
                                        ! M3 = A C' B D
                                        call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,i,j)
                                        call TwoOptMove(inst%npol,newtour,tour3,newx,sol3,newcost,cost3,i,k)
                                        if ( alcallbcd ) call BCD(inst,count,tour3,sol3,cost3)
                                        if ( cost3 .lt. bestcost ) then
                                            bestcost = cost3; bestour = tour3; bestsol = sol3
                                            if ( .not. bestimp ) then
                                                stop3opt = .true.
                                                exit seq_outer
                                            end if
                                        end if
                                    else
                                        ! M4 = A C B D
                                        call TwoOptMove(inst%npol,tour,newtour,x,newx,cost,newcost,j,k)
                                        call TwoOptMove(inst%npol,newtour,tour2,newx,sol2,newcost,cost2,i,k)
                                        call TwoOptMove(inst%npol,tour2,tour4,sol2,sol4,cost2,cost4,i+k-j,k)
                                        if ( alcallbcd ) call BCD(inst,count,tour4,sol4,cost4)
                                        if ( cost4 .lt. bestcost ) then
                                            bestcost = cost4; bestour = tour4; bestsol = sol4
                                            if ( .not. bestimp ) then
                                                stop3opt = .true.
                                                exit seq_outer
                                            end if
                                        end if
                                    end if

                                end do
                            end do
                        end do
                    end do
                end do
            end do seq_outer
        end if

        if ( .not.(alcallbcd) ) then
            call BCD(inst,count,bestour,bestsol,bestcost)
        end if

        tour = bestour
        x = bestsol
        cost = bestcost
        
    contains

        ! Cyclic successor (d = 1) or predecessor (d = -1) of position p
        pure function nbpos(p,d) result(q)
            integer, intent(in) :: p,d
            integer :: q
            if ( d .gt. 0 ) then
                q = merge(1, p+1, p .eq. inst%npol)
            else
                q = merge(inst%npol, p-1, p .eq. 1)
            end if
        end function nbpos

        ! Break position of the tour edge (p, nbpos(p,d)), i.e. the smaller
        ! endpoint of the edge in the cyclic order
        pure function brkpos(p,d) result(b)
            integer, intent(in) :: p,d
            integer :: b
            if ( d .gt. 0 ) then
                b = p
            else
                b = merge(inst%npol, p-1, p .eq. 1)
            end if
        end function brkpos

        ! Is the unordered pair (p,q) among the three pairs stored in s?
        pure function pairin(p,q,s) result(ok)
            integer, intent(in) :: p,q,s(2,3)
            logical :: ok
            ok = any( ( s(1,:) .eq. p .and. s(2,:) .eq. q ) .or. &
                      ( s(1,:) .eq. q .and. s(2,:) .eq. p ) )
        end function pairin

        ! Fast distance between the visiting points of two positions
        pure function edge(a, b) result(d)
            integer, intent(in) :: a, b
            real(kind=8) :: d, dx, dy
            dx = x(1,a) - x(1,b)
            dy = x(2,a) - x(2,b)
            d = sqrt( dx * dx + dy * dy )
        end function edge

    end subroutine G3opt

    ! *****************************************************************
    ! *****************************************************************

    subroutine Ginsert(inst,count,tour,x,cost,alcallbcd,bestimp)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        logical, intent(in) :: alcallbcd
        ! Improvement strategy of this neighborhood:
        !   .false. = first improvement (stop at the first improving move)
        !   .true.  = best improvement  (scan the whole neighborhood and
        !             apply the cheapest improving move found)
        ! The candidate-list pruning is the SAME in both: for the swap and
        ! the 2-opt it is exact, so the best move of the pruned neighborhood
        ! is the best move of the full one.
        logical, intent(in) :: bestimp
        real(kind=8), intent(inout) :: cost

        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol)

        ! This routine applies the relocation (insertion) heuristic, with first
        ! or best improvement according to bestimp, + BCD in each new
        ! permutation if alcallbcd = true, or BCD only in the final permutation,
        ! otherwise.
        !
        ! CANDIDATE LISTS. Relocating the node at position i so that it lands
        ! between positions a and a+1 removes (i-1,i), (i,i+1) and (a,a+1), and
        ! inserts (i-1,i+1), (a,i) and (i,a+1). Pairing them:
        !   [d(i-1,i) - d(a,i)] + [d(i,i+1) - d(i,a+1)] + [d(a,a+1) - d(i-1,i+1)]
        ! The first two brackets are fixed-radius conditions on the RELOCATED
        ! node, both read from the candidate list of tour(i):
        !   d(a,i)   < d(i-1,i)  =>  a   among the candidates of tour(i)
        !   d(i,a+1) < d(i,i+1)  =>  a+1 among the candidates of tour(i)
        ! so a single scan of cand(tour(i)), with radius equal to the longer of
        ! the two edges adjacent to i, covers both.
        !
        ! CAVEAT: unlike the swap and the 2-opt, this scan is NOT exact. The
        ! third bracket is not a proximity condition - it says the broken edge
        ! (a,a+1) must be longer than the closing edge d(i-1,i+1) - so a move
        ! that improves ONLY through it is not seen. This is the usual
        ! compromise of granular search: a node whose relocation pays off
        ! almost always lands next to one of its nearest neighbours. The size
        ! of the loss is measurable with the same local-optimum test used for
        ! the 2-opt and the 3-opt.
        ! Cost drops from O(N^2) to O(N*K).

        ! LOCAL SCALARS
        logical :: stopinsert
        integer :: i,j,m,a,ap,im,ip,pass
        real(kind=8) :: insertcost,bestcost,rprev,rnext,rad

        ! LOCAL ARRAYS
        integer :: insertour(inst%npol),bestour(inst%npol),pos(inst%npol)
        real(kind=8) :: insertsol(2,inst%npol),bestsol(2,inst%npol)

        count%insercall = count%insercall + 1

        bestour = tour
        bestsol = x
        bestcost = cost

        do i = 1, inst%npol
            pos(tour(i)) = i
        end do

        stopinsert = .false.

        do i = 1, inst%npol
            if ( stopinsert ) exit

            im = merge(inst%npol, i-1, i .eq. 1)
            ip = merge(1, i+1, i .eq. inst%npol)
            rprev = norm2( x(1:2,im) - x(1:2,i) )
            rnext = norm2( x(1:2,i) - x(1:2,ip) )
            rad = max( rprev, rnext )

            do m = 1, inst%ncand
                if ( stopinsert ) exit
                ! The list is ordered: no later candidate can be closer
                if ( inst%canddist(m,tour(i)) .ge. rad ) exit

                ap = pos(inst%cand(m,tour(i)))

                ! pass 1: the candidate is a   (i lands right after it)
                ! pass 2: the candidate is a+1 (i lands right before it)
                do pass = 1, 2
                    if ( pass .eq. 1 ) then
                        if ( inst%canddist(m,tour(i)) .ge. rprev ) cycle
                        a = ap
                    else
                        if ( inst%canddist(m,tour(i)) .ge. rnext ) cycle
                        a = merge(inst%npol, ap-1, ap .eq. 1)
                    end if

                    ! a == i or a == i-1 leaves the tour unchanged
                    if ( a .eq. i .or. a .eq. im ) cycle

                    ! Position expected by InsertMove: it inserts AT j, i.e.
                    ! between j and j+1 when j > i, and between j-1 and j
                    ! when j < i
                    if ( a .gt. i ) then
                        j = a
                    else
                        j = a + 1
                    end if
                    if ( j .lt. 1 .or. j .gt. inst%npol .or. j .eq. i ) cycle

                    call InsertMove(inst%npol,tour,insertour,x,insertsol,cost,insertcost,i,j)
                    if ( alcallbcd ) then
                        call BCD(inst,count,insertour,insertsol,insertcost)
                    end if
                    if ( insertcost .lt. bestcost ) then
                        bestcost = insertcost
                        bestour = insertour
                        bestsol = insertsol
                        if ( .not. bestimp ) then
                            stopinsert = .true.
                            exit
                        end if
                    end if
                end do
            end do
        end do

        if ( .not.(alcallbcd) ) then
            call BCD(inst,count,bestour,bestsol,bestcost)
        end if

        tour = bestour
        x = bestsol
        cost = bestcost

    end subroutine Ginsert

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine Gutin(inst,count,tour,x,cost,seed,cardZ)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        integer, intent(in) :: cardZ
        real(kind=8), intent(inout) :: cost,seed
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine must perform a search on a Gutin (or Assignment)
        ! Neighborhood of a given tour. The points are adjusted during 
        ! the search using the Minpol algorithm.

        ! LOCAL SCALARS
        integer, parameter :: NMAX = 1000
        real(kind=8), parameter :: SCALE_FACTOR = 10000.0d0
        integer :: i,j,k,s,T,prev,next,num_objects,shift,r,temp,idx
        real(kind=8) :: newcost,gmin

        ! LOCAL ARRAYS
        integer :: newtour(inst%npol),A(NMAX,NMAX+1),C(NMAX),Z(inst%npol),&
        zbool(inst%npol),objects(inst%npol),config(inst%npol)
        ! OPTIMIZATION: xvisit was dimensioned (npol,npol,2) - up to dozens of MB
        ! on the stack per call - while only s <= cardZ rows/columns are used.
        ! The coordinate is now the first index for contiguous memory access.
        real(kind=8) :: xmin(2),newx(2,inst%npol),xvisit(2,cardZ,cardZ)

        ! EXTERNAL SUBROUTINES
        external :: ASSCT

        count%gutincall = count%gutincall + 1

        ! ---------------------------------------------------------
        ! 1. Generate the Z set of exact size 'cardZ'
        ! ---------------------------------------------------------
        ! NMAX is the hard limit of ASSCT, which declares A(NMAX,NMAX+1) and
        ! C(NMAX) as fixed-size F77 arrays: s indexes both, so a larger s
        ! writes past the end of them. It cannot happen while cardZ tops out
        ! at 30 in parameters.txt, but the cap belongs in the code rather than
        ! in the grid - widening the cardZ range must not be able to turn into
        ! silent memory corruption.
        s = min(cardZ, inst%npol / 2, NMAX)

        ! ---------------------------------------------------------
        ! CONSTRUCTIVE NON-CONSECUTIVE SAMPLING
        ! ---------------------------------------------------------
        ! 1. Define the number of total discrete blocks
        num_objects = inst%npol - s
        
        ! 2. Create the blocks: 's' objects are [1,0], the rest are [0]
        ! We represent [1,0] blocks as '1', and [0] blocks as '0'
        objects(1:num_objects) = 0
        if (s .gt. 0) objects(1:s) = 1

        ! 3. Shuffle the objects array randomly (Fisher-Yates Shuffle)
        do i = num_objects, 2, -1
            r = floor(drand(seed) * i) + 1
            temp = objects(i)
            objects(i) = objects(r)
            objects(r) = temp
        end do

        ! 4. Expand the blocks into a linear configuration array
        idx = 1
        do i = 1, num_objects
            if (objects(i) .eq. 1) then
                config(idx) = 1
                config(idx+1) = 0
                idx = idx + 2
            else
                config(idx) = 0
                idx = idx + 1
            end if
        end do

        ! 5. Apply a random circular shift to cover all wrap-around possibilities
        shift = floor(drand(seed) * inst%npol)
        zbool(1:inst%npol) = 0

        do i = 1, inst%npol
            idx = mod(i - 1 + shift, inst%npol) + 1
            zbool(idx) = config(i)
        end do

        ! 6. Extract the final Z indices sequentially
        s = 0
        do i = 1, inst%npol
            if (zbool(i) .eq. 1) then
                s = s + 1
                Z(s) = i
            end if
        end do

        ! ---------------------------------------------------------
        ! 2. Build the Assignment Matrix A
        ! A(i,j): Cost of inserting Polygon Z(i) into the Slot Z(j)
        ! ---------------------------------------------------------
        ! OPTIMIZATION: 'j' is the outer loop for Column-Major memory access
        ! and to prevent redundant calculations of 'prev' and 'next'.
        do j = 1, s
            ! Identify the gap bounds for Slot Z(j) ONLY ONCE per column
            prev = merge(inst%npol, Z(j)-1, Z(j) == 1)
            next = merge(1, Z(j)+1, Z(j) == inst%npol)
            do i = 1, s
                if ( i .eq. j ) then
                    xvisit(1:2,i,j) = x(1:2,Z(i)) ! Stores the Z(j) visiting point that belongs to the polygon Z(i)
                    gmin = norm2( xvisit(1:2,i,j) - x(1:2,prev) ) + &
                    norm2( xvisit(1:2,i,j) - x(1:2,next) )
                else
                    ! If the polygon has only one vertex, there is nothing to optimize
                    if ( inst%nvp(tour(Z(i))) .gt. 1 ) then
                        xmin = x(1:2,Z(i))
                        call minpol(inst,tour(Z(i)),x(1:2,prev),x(1:2,next),xmin,gmin)
                        xvisit(1:2,i,j) = xmin(1:2)
                    else
                        xvisit(1:2,i,j) = x(1:2,Z(i)) ! Stores the Z(j) visiting point that belongs to the polygon Z(i)
                        gmin = norm2( xvisit(1:2,i,j) - x(1:2,prev) ) + &
                        norm2( xvisit(1:2,i,j) - x(1:2,next) )
                    end if
                end if
                ! Apply scaling factor to preserve decimal precision for ASSCT
                A(i,j) = nint(gmin * SCALE_FACTOR)
            end do
        end do

        ! ---------------------------------------------------------
        ! 3. Solve and Reconstruct - solves the assignment problem
        ! ---------------------------------------------------------
        call ASSCT(s, A, C, T)
        ! Initialize newtour and newx with tour and x, since only the positions in Z will be changed
        newtour = tour
        newx = x
        do k = 1, s
            ! C(k) is the Row (Polygon i) assigned to Column k (Slot j).
            newtour(Z(k)) = tour(Z(C(k)))
            newx(1:2,Z(k)) = xvisit(1:2,C(k),k)
        end do

        call evalf(inst%npol,newx,newcost)
        call BCD(inst,count,newtour,newx,newcost)

        ! OPTIMIZATION: Only accept the move if it strictly improves the tour
        if ( newcost .lt. cost ) then
            tour = newtour
            x = newx
            cost = newcost
        end if
    end subroutine Gutin

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine StringRelocN(inst,count,tour,x,cost,strlen,alcallbcd,reverse)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        logical, intent(in) :: alcallbcd
        integer, intent(in) :: strlen,reverse 
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine performs the String Relocation heuristic (Schmidt &
        ! Irnich 2022) with best improvement + BCD in each new permutation if
        ! alcallbcd = true, or BCD only in the final permutation, otherwise.
        !
        ! CANDIDATE LISTS. Removing the string (i..i+k) and inserting it between
        ! j and j+1 removes (i-1,i), (i+k,i+k+1), (j,j+1) and inserts, in normal
        ! orientation, (i-1,i+k+1), (j,i), (i+k,j+1). Pairing the removed edges
        ! adjacent to the string with the inserted ones that reconnect it:
        !   [d(i-1,i)     - d(j,i)]     -> j   among the candidates of tour(i),
        !                                    radius d(i-1,i)
        !   [d(i+k,i+k+1) - d(i+k,j+1)] -> j+1 among the candidates of tour(i+k),
        !                                    radius d(i+k,i+k+1)
        ! The reversed orientation swaps the two string endpoints in the
        ! connections, so scanning the candidates of BOTH endpoints and taking
        ! j and j-1 for each covers the four connection cases.
        !
        ! CAVEAT: like the insertion, this scan is NOT exact. The third bracket
        ! [d(j,j+1) - d(i-1,i+k+1)] is not a proximity condition, so a move that
        ! improves only through it is not seen. Measured on random tours, the
        ! best move outside the scan beats the best inside it in about 2% of the
        ! cases with full lists - the usual granular-search compromise. It can
        ! be made exact later with an extra scan over the tour edges sorted by
        ! decreasing length. Cost drops from O(N^2 * strlen) to O(N * strlen * K).

        ! LOCAL SCALARS
        integer :: i,j,k,kmax,inv_idx,num_inv,m,ss,se,jj,cnt_j
        real(kind=8) :: bestcost,srcost,rstart,rend
        logical :: is_inplace

        ! LOCAL ARRAYS
        integer :: bestour(inst%npol),srtour(inst%npol),pos(inst%npol),jlist(4*inst%ncand)
        real(kind=8) :: string(2,strlen),bestsol(2,inst%npol),srx(2,inst%npol)
        logical :: do_inv(2)

        count%relocall = count%relocall + 1

        bestour = tour
        bestsol = x
        bestcost = cost

        do i = 1, inst%npol
            pos(tour(i)) = i
        end do

        num_inv = 1
        do_inv(1) = .false.
        if ( reverse .eq. 1 ) then
            num_inv = 2
            do_inv(2) = .true.
        end if

        do i = 1, inst%npol-1
            kmax = min(strlen-1, inst%npol-i)
            string(:,1:kmax+1) = x(:,i:i+kmax)
            do k = 1, kmax
                ss = i
                se = i + k

                ! Radii: length of the two tour edges adjacent to the string
                rstart = norm2( x(1:2,merge(inst%npol,i-1,i.eq.1)) - x(1:2,ss) )
                rend   = norm2( x(1:2,se) - x(1:2,merge(1,se+1,se.eq.inst%npol)) )

                ! ---- build the candidate list of insertion positions j ----
                cnt_j = 0
                do m = 1, inst%ncand
                    if ( inst%canddist(m,tour(ss)) .ge. rstart ) exit
                    jj = pos(inst%cand(m,tour(ss)))
                    call pushj(jj)
                    call pushj( merge(inst%npol, jj-1, jj.eq.1) )
                end do
                do m = 1, inst%ncand
                    if ( inst%canddist(m,tour(se)) .ge. rend ) exit
                    jj = pos(inst%cand(m,tour(se)))
                    call pushj( merge(inst%npol, jj-1, jj.eq.1) )
                    call pushj(jj)
                end do

                do m = 1, cnt_j
                    j = jlist(m)
                    ! Same validity window as the exhaustive scan
                    if ( j .lt. i .or. j .gt. i+k ) then
                        is_inplace = (j == i - 1) .or. (i == 1 .and. j == inst%npol)
                        do inv_idx = 1, num_inv
                            if ( is_inplace .and. .not. do_inv(inv_idx) ) cycle
                            call StringMove(inst%npol,tour,srtour,x,srx,cost,srcost,i,k,j,&
                            string,strlen,do_inv(inv_idx))
                            if ( alcallbcd ) then
                                call BCD(inst,count,srtour,srx,srcost)
                            end if
                            if ( srcost .lt. bestcost ) then
                                bestcost = srcost
                                bestour = srtour
                                bestsol = srx
                            end if
                        end do
                    end if
                end do
            end do
        end do

        if ( .not.(alcallbcd) ) then
            call BCD(inst,count,bestour,bestsol,bestcost)
        end if

        tour = bestour
        x = bestsol
        cost = bestcost

    contains

        ! Append j to jlist, skipping duplicates (list is short, linear scan)
        subroutine pushj(jv)
            integer, intent(in) :: jv
            integer :: t
            do t = 1, cnt_j
                if ( jlist(t) .eq. jv ) return
            end do
            cnt_j = cnt_j + 1
            jlist(cnt_j) = jv
        end subroutine pushj

    end subroutine StringRelocN

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine BalaSimonetti(inst,count,tour,x,cost,bsk)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        integer, intent(in) :: bsk
        real(kind=8), intent(inout) :: cost

        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 
        
        ! This routine must return the best k-Balas-Simonetti neighbor
        ! (based on the paper N. Simonetti e E. Balas. “Implementation of a
        ! linear time algorithm for certain generalized traveling salesman 
        ! problems”. Integer Programming and Combinatorial Optimization 
        ! (Proceedings of IPCO 5). 1996) and a shortest path algorithm is 
        ! used to obtain the best k-BS neighbor + BCD only in the final 
        ! (best) permutation.

        ! LOCAL SCALARS
        integer ::  k,i,nnodes,lsize,s,t
        real(kind=8) :: djcost,newcost

        ! LOCAL ARRAYS
        integer :: djtour(inst%npol),citour(inst%npol),newtour(inst%npol),&
        V(inst%vsize),L(inst%lwsize),vcit(inst%vsize),prev_ptr(inst%vsize)
        real(kind=8) :: newsol(2,inst%npol),W(inst%lwsize),vcoorper(2,inst%vsize)

        count%bscall = count%bscall + 1

        nnodes = -1

        if ( bsk .eq. 2 ) then
            ! write(*,*) 'Balas Simonetti - k = 2'
            nnodes = 3 * inst%npol - 1
            lsize = 5 * inst%npol - 4
            call AdjLists(inst,tour,x,nnodes,lsize,V,L,W,vcit,vcoorper,2)
        else if ( bsk .eq. 3 ) then
            ! write(*,*) 'Balas Simonetti - k = 3'
            nnodes = 8 * inst%npol - 6
            lsize = 17 * inst%npol - 22
            call AdjLists(inst,tour,x,nnodes,lsize,V,L,W,vcit,vcoorper,3)
        end if

        s = 1           ! Source node
        t = nnodes      ! Sink node
        ! Call a O(V+E) DAG shortest path solver
        call ShortestPath(inst,s,t,nnodes,V,L,W,prev_ptr,djcost)

        ! BUGFIX: Safe-guard against unreachable sinks.
        ! If the DAG couldn't find a path, exit to prevent a segfault on reconstruction.
        if ( djcost .ge. huge(1.0d0) ) return

        ! Get the shortest path tour
        djtour(1) = s
        djtour(inst%npol) = prev_ptr(t)
        do i = inst%npol-1, 2, -1 
            djtour(i) = prev_ptr(djtour(i+1))
        end do

        do k = 1, inst%npol
            citour(k) = vcit(djtour(k))
        end do
        do k = 1, inst%npol
            newtour(k) = tour(citour(k))
            newsol(1:2,k) = x(1:2,citour(k))
        end do

        call evalf(inst%npol,newsol,newcost)
        call BCD(inst,count,newtour,newsol,newcost)

        if ( newcost .lt. cost ) then
            tour = newtour
            x = newsol
            cost = newcost
        end if
    end subroutine BalaSimonetti

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine AdjLists(inst,tour,x,nnodes,lsize,V,L,W,vcit,vcoorper,algo)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst

        ! SCALAR ARGUMENTS
        integer, intent(in) :: nnodes,lsize,algo

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(inst%npol)
        integer, intent(out) :: V(inst%vsize),L(inst%lwsize),vcit(inst%vsize)
        real(kind=8), intent(in) :: x(2,inst%npol)
        real(kind=8), intent(out) :: W(inst%lwsize),vcoorper(2,nnodes)
        
        ! This routine must build the adjacency lists V, L and W. 
        ! V(1:Nnodes): each entry V(i) points to the nodes adjacent to i in the vector L.
        ! L(1:lsize): L[V(i):V(i+1)-1] contains the neighbors of node i.
        ! W(1:lsize): W[V(i):V(i+1)-1] contains the distance between node i and its neighbors L[V(i):V(i+1)-1].
        ! lsize is the efective size, while lwsize is an upper bound.

        ! LOCAL SCALARS
        integer ::  k,i,j,delta,alpha,beta
        real(kind=8), parameter :: infty = huge( 1.0d0 )

        if ( algo .eq. 1 ) then
            ! write(*,*) 'Build V, L, W for Dijkstra'
            delta = 0
            do k = 1, inst%npol
                do j = 1, inst%nvp(tour(k))
                    vcoorper(1:2, delta + j) = inst%vcoor(1:2,j,tour(k))
                end do
                delta = delta + inst%nvp(tour(k))
            end do
            do j = 1, inst%nvp(tour(1))
                vcoorper(1:2, inst%nvert + j) = inst%vcoor(1:2,j,tour(1))
            end do

            alpha = 0
            beta = 0
            delta = 0

            V(1) = 1
            do i = 1, inst%npol
                if ( i .lt. inst%npol ) then
                    beta = i+1
                else
                    beta = 1
                end if

                do j = 1, inst%nvp(tour(i))
                    V(j+1+delta) = V(j+delta) + inst%nvp(tour(beta))
                    L(V(j+delta)) = inst%nvp(tour(i)) + 1 + alpha
                    ! W(V(j+delta)) = norm2(vcoorper(1:2,j+delta) - vcoorper(1:2,L(V(j+delta))))
                    W(V(j+delta)) = dist1(j+delta, L(V(j+delta)))
                    do k = V(j+delta), V(j+1+delta)-2
                        L(k+1) = L(k) + 1
                        ! W(k+1) = norm2(vcoorper(1:2,j+delta) - vcoorper(1:2,L(k+1)))
                        W(k+1) = dist1(j+delta, L(k+1))
                    end do
                end do

                delta = delta + inst%nvp(tour(i))
                alpha = alpha + inst%nvp(tour(i))
            end do

            do j = inst%nvert+1, nnodes-1
                V(j+1) = V(j) + 1
                L(V(j)) = -1
                W(V(j)) = infty
            end do

            L(lsize) = -1
            W(lsize) = infty

        else if ( algo .eq. 2 ) then
            ! write(*,*) 'Build V, L, W for Balas Simonetti with k=2' 

            vcit(1) = 1     ! Each component k of vcit denotes the city vcit(k) associated with node k of G*
            k = 2           ! k: denotes the G* nodes; i: denotes de layers Vi
            do i = 2, inst%npol-1
                vcit(k) = i
                vcit(k+1) = i+1
                vcit(k+2) = i-1
                k = k+3
            end do
            vcit(k) = inst%npol
            vcit(k+1) = 1
            vcit(k+2) = inst%npol-1
            vcit(nnodes) = 1

            V(1) = 1
            L(1) = 2
            L(2) = 3
            ! W(1) = norm2( x(1:2,vcit(1)) - x(1:2,vcit(L(1))) )
            ! W(2) = norm2( x(1:2,vcit(1)) - x(1:2,vcit(L(2))) )
            W(1) = dist23(1, L(1))
            W(2) = dist23(1, L(2))

            k = 2           ! Denotes de nodes of G*
            j = 3           ! Denotes de position in L and W
            
            do i = 2, inst%npol-1
                V(k) = j
                L(j) = k+3
                L(j+1) = k+4
                ! W(j) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j+1))) )
                W(j) = dist23(k, L(j))
                W(j+1) = dist23(k, L(j+1))

                j = j+2

                V(k+1) = j
                L(j) = k+5
                ! W(j) = norm2( x(1:2,vcit(k+1)) - x(1:2,vcit(L(j))) )
                W(j) = dist23(k+1, L(j))

                j = j+1

                V(k+2) = j
                L(j) = k+3
                L(j+1) = k+4
                ! W(j) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j+1))) )
                W(j) = dist23(k+2, L(j))
                W(j+1) = dist23(k+2, L(j+1))

                j = j+2
                k = k+3
            end do

            V(k) = j
            L(j) = k+3
            ! W(j) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j))) )
            W(j) = dist23(k, L(j))

            j = j+1

            V(k+1) = j
            L(j) = -1
            W(j) = infty

            j = j+1

            V(k+2) = j
            L(j) = k+3
            ! W(j) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j))) )
            W(j) = dist23(k+2, L(j))

            V(nnodes) = lsize
            L(lsize) = -1
            W(lsize) = infty

        else if ( algo .eq. 3 ) then
            ! write(*,*) 'Build V, L, W for Balas Simonetti with k=3' 
            ! Layer 1
            vcit(1) = 1
            k = 2           ! k: denotes the G* nodes; i: denotes de layers Vi

            ! Layer 2
            vcit(k) = 2
            vcit(k+1) = 3
            vcit(k+2) = 1
            vcit(k+3) = 4
            vcit(k+4) = 3
            vcit(k+5) = 1
            vcit(k+6) = 2
            vcit(k+7) = 1 ! this node is not expected to be reached, but it cannot be left at zero: the loop over V, L and W indexes this position of x, and x has no position 0
            k = k+8

            do i = 3, inst%npol-2
                vcit(k) = i
                vcit(k+1) = i+1
                vcit(k+2) = i-1
                vcit(k+3) = i+2
                vcit(k+4) = i+1
                vcit(k+5) = i-1
                vcit(k+6) = i
                vcit(k+7) = i-2
                k = k+8
            end do

            ! Layer inst%npol-1
            vcit(k) = inst%npol-1
            vcit(k+1) = inst%npol
            vcit(k+2) = inst%npol-2
            vcit(k+3) = 1   ! this one would lead to node inst%npol+1, which does not exist
            vcit(k+4) = inst%npol
            vcit(k+5) = inst%npol-2
            vcit(k+6) = inst%npol-1
            vcit(k+7) = inst%npol-3
            k = k+8

            ! Layer inst%npol
            vcit(k) = inst%npol
            vcit(k+1) = 1
            vcit(k+2) = inst%npol-1
            vcit(k+3) = 1
            vcit(k+4) = 1
            vcit(k+5) = inst%npol-1
            vcit(k+6) = inst%npol
            vcit(k+7) = inst%npol-2
            
            ! Layer inst%npol+1
            vcit(nnodes) = 1

            V(1) = 1
            L(1) = 2
            L(2) = 3
            L(3) = 5
            ! W(1) = norm2( x(1:2,vcit(1)) - x(1:2,vcit(L(1))) )
            ! W(2) = norm2( x(1:2,vcit(1)) - x(1:2,vcit(L(2))) )
            ! W(3) = norm2( x(1:2,vcit(1)) - x(1:2,vcit(L(3))) )
            W(1) = dist23(1, L(1))
            W(2) = dist23(1, L(2))
            W(3) = dist23(1, L(3))

            k = 2           ! Denotes de nodes of G*
            j = 4           ! Denotes de position in L and W
            do i = 2, inst%npol-1
                V(k) = j
                L(j) = k+8
                L(j+1) = k+9
                L(j+2) = k+11
                ! W(j) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j+1))) )
                ! W(j+2) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j+2))) )
                W(j) = dist23(k, L(j))
                W(j+1) = dist23(k, L(j+1))
                W(j+2) = dist23(k, L(j+2))

                j = j+3

                V(k+1) = j
                L(j) = k+10
                L(j+1) = k+12
                ! W(j) = norm2( x(1:2,vcit(k+1)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k+1)) - x(1:2,vcit(L(j+1))) )
                W(j) = dist23(k+1, L(j))
                W(j+1) = dist23(k+1, L(j+1))

                j = j+2

                V(k+2) = j
                L(j) = k+8
                L(j+1) = k+9
                L(j+2) = k+11
                ! W(j) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j+1))) )
                ! W(j+2) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j+2))) )
                W(j) = dist23(k+2, L(j))
                W(j+1) = dist23(k+2, L(j+1))
                W(j+2) = dist23(k+2, L(j+2))

                j = j+3

                V(k+3) = j
                L(j) = k+13
                L(j+1) = k+14
                ! W(j) = norm2( x(1:2,vcit(k+3)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k+3)) - x(1:2,vcit(L(j+1))) )
                W(j) = dist23(k+3, L(j))
                W(j+1) = dist23(k+3, L(j+1))

                j = j+2

                V(k+4) = j
                L(j) = k+15
                ! W(j) = norm2( x(1:2,vcit(k+4)) - x(1:2,vcit(L(j))) )
                W(j) = dist23(k+4, L(j))

                j = j+1

                V(k+5) = j
                L(j) = k+10
                L(j+1) = k+12
                ! W(j) = norm2( x(1:2,vcit(k+5)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k+5)) - x(1:2,vcit(L(j+1))) )
                W(j) = dist23(k+5, L(j))
                W(j+1) = dist23(k+5, L(j+1))

                j = j+2

                V(k+6) = j
                L(j) = k+15
                ! W(j) = norm2( x(1:2,vcit(k+6)) - x(1:2,vcit(L(j))) )
                W(j) = dist23(k+6, L(j))

                j = j+1

                V(k+7) = j
                L(j) = k+8
                L(j+1) = k+9
                L(j+2) = k+11
                ! W(j) = norm2( x(1:2,vcit(k+7)) - x(1:2,vcit(L(j))) )
                ! W(j+1) = norm2( x(1:2,vcit(k+7)) - x(1:2,vcit(L(j+1))) )
                ! W(j+2) = norm2( x(1:2,vcit(k+7)) - x(1:2,vcit(L(j+2))) )
                W(j) = dist23(k+7, L(j))
                W(j+1) = dist23(k+7, L(j+1))
                W(j+2) = dist23(k+7, L(j+2))

                k = k+8
                j = j+3
            end do

            ! Layer Vn
            V(k) = j
            L(j) = k+8
            ! W(j) = norm2( x(1:2,vcit(k)) - x(1:2,vcit(L(j))) )
            W(j) = dist23(k, L(j))

            j = j+1

            V(k+1) = j
            L(j) = -1
            W(j) = infty

            j = j+1

            V(k+2) = j
            L(j) = k+8
            ! W(j) = norm2( x(1:2,vcit(k+2)) - x(1:2,vcit(L(j))) )
            W(j) = dist23(k+2, L(j))

            j = j+1

            V(k+3) = j
            L(j) = -1
            W(j) = infty

            j = j+1

            V(k+4) = j
            L(j) = -1
            W(j) = infty

            j = j+1

            V(k+5) = j
            L(j) = -1
            W(j) = infty

            j = j+1

            V(k+6) = j
            L(j) = -1
            W(j) = infty

            j = j+1

            V(k+7) = j
            L(j) = k+8
            ! W(j) = norm2( x(1:2,vcit(k+7)) - x(1:2,vcit(L(j))) )
            W(j) = dist23(k+7, L(j))

            ! Layer V_n+1
            V(nnodes) = lsize
            L(lsize) = -1
            W(lsize) = infty
        end if

        ! =========================================================
        ! INTERNAL PURE FUNCTIONS FOR ZERO-OVERHEAD SCALAR MATH
        ! =========================================================
        contains 
            ! Distance calculator for Algo 1 (uses vcoorper array)
            pure function dist1(a,b) result(d)
                integer, intent(in) :: a,b
                real(kind=8) :: d,dx,dy
                dx = vcoorper(1,a) - vcoorper(1,b)
                dy = vcoorper(2,a) - vcoorper(2,b)
                d = sqrt( dx * dx + dy * dy )
            end function dist1

            ! Distance calculator for Algo 2 & 3 (uses x and vcit arrays)
            pure function dist23(a,b) result(d)
                integer, intent(in) :: a,b
                real(kind=8) :: d,dx,dy
                dx = x(1, vcit(a)) - x(1, vcit(b))
                dy = x(2, vcit(a)) - x(2, vcit(b))
                d = sqrt( dx * dx + dy * dy )
            end function dist23

    end subroutine AdjLists

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine ShortestPath(inst,s,t,nnodes,V,L,W,prev_ptr,cost)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst

        ! SCALAR ARGUMENTS
        integer, intent(in) :: s,t,nnodes
        real(kind=8), intent(out) :: cost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: V(inst%vsize),L(inst%lwsize) 
        integer, intent(out) :: prev_ptr(inst%vsize)
        real(kind=8), intent(in) :: W(inst%lwsize)
        
        ! This algorithm solves the shortest path on a Directed Acyclic Graph (DAG) 
        ! in linear O(V + E) time by taking advantage of topological ordering.

        ! LOCAL SCALARS
        integer ::  i,j,k
        real(kind=8), parameter :: infty = huge( 1.0d0 )
        real(kind=8) :: label

        ! LOCAL ARRAYS
        real(kind=8) :: adist(inst%vsize)
        
        ! =========================================
        ! 1. Initialization
        ! =========================================
        adist(1:nnodes) = infty
        prev_ptr(1:nnodes) = -1
        adist(s) = 0.0d0
        
        ! =========================================
        ! 2. O(V + E) DAG Topological Relaxation
        ! =========================================
        do i = 1, nnodes-1
            ! If the node is unreachable from the source, skip it entirely
            if ( adist(i) .eq. infty ) cycle
            ! Relax all outgoing edges from node i
            do k = V(i), V(i+1)-1
                j = L(k)
                ! Ensure the edge points to a valid node
                if ( j .gt. 0 ) then
                    label = adist(i) + W(k)
                    ! If we found a shorter path to node j, update it
                    if ( label .lt. adist(j) ) then
                        adist(j) = label
                        prev_ptr(j) = i
                    end if
                end if
            end do
            ! Because the graph is topologically sorted, once we process node i,
            ! its shortest path distance is permanently locked. No need to look back!
        end do
        ! The cost is simply the locked-in shortest distance to the sink node
        cost = adist(t)
    end subroutine ShortestPath

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine NeighborhoodSearch(inst,param,count,jviz,tour,x,cost,alcallbcd)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(parameter_type), intent(inout) :: param
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        logical, intent(in) :: alcallbcd
        integer, intent(in) :: jviz
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine must apply a neighborhood search.
        ! The neighborhood structure depends on the value of jviz.
        !
        ! IMPROVEMENT STRATEGY. Four of the eight neighborhoods admit both
        ! first and best improvement - the 2-opt (jviz 4), the swap (5), the
        ! insertion (6) and the 3-opt (8) - and param%bestfirst picks which:
        !     0 = first improvement    1 = best improvement
        ! The other four are not local searches over an enumerable
        ! neighborhood (Bala-Simonetti and Gutin solve a subproblem to
        ! optimality, the double bridge and the string relocation are applied
        ! as constructed), so there is nothing to choose there.

        count%nscal = count%nscal+1

        if (jviz .eq. 1) then
            call BalaSimonetti(inst,count,tour,x,cost,param%bsk)
        else if (jviz .eq. 2) then
            call DoubleBridgeN(inst,count,tour,x,cost)
        ! else if (jviz .eq. 3) then
        !     call BalaSimonetti(inst,count,tour,x,cost,3)
        else if (jviz .eq. 3) then
            call Gutin(inst,count,tour,x,cost,param%seed,param%cardZ) 
        else if (jviz .eq. 4) then
            call G2opt(inst,count,tour,x,cost,alcallbcd,param%bestfirst .eq. 1)
        else if (jviz .eq. 5) then
            call SwapN(inst,count,tour,x,cost,alcallbcd,param%bestfirst .eq. 1)
        else if (jviz .eq. 6) then
            call Ginsert(inst,count,tour,x,cost,alcallbcd,param%bestfirst .eq. 1)
        else if (jviz .eq. 7) then
            call StringRelocN(inst,count,tour,x,cost,param%strlen,alcallbcd,param%reverse)
        else if (jviz .eq. 8) then
            call G3opt(inst,count,tour,x,cost,alcallbcd,param%bestfirst .eq. 1)
        end if

    end subroutine NeighborhoodSearch

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine PerturbDB(inst,count,tour,x,cost,seed,numdbmoves)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        integer, intent(in) :: numdbmoves
        real(kind=8), intent(inout) :: seed
        real(kind=8), intent(inout) :: cost   ! On entry, must hold the cost of the solution (tour,x)

        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol) 
        real(kind=8), intent(inout) :: x(2,inst%npol)
        
        ! This routine must generate a sequence of 'numdbmoves' random 
        ! double-bridge neighbors for the ILS perturbation step.

        ! LOCAL SCALAR
        integer :: i,j,iter
        real(kind=8) :: newcost

        ! LOCAL ARRAY
        integer :: newtour(inst%npol),orddb(4)
        real(kind=8) :: newx(2,inst%npol)

        ! Loop to perform 'numdbmoves' consecutive Double-Bridge moves
        do iter = 1, numdbmoves

            ! Perform a random double-bridge move. Condition: inst%npol > 4
            orddb(1) = floor((inst%npol-1)*drand(seed)) + 1
            orddb(2) = floor((inst%npol-1)*drand(seed)) + 1
            orddb(3) = floor((inst%npol-1)*drand(seed)) + 1
            orddb(4) = floor((inst%npol-1)*drand(seed)) + 1
            
            do while ( (abs( orddb(1)-orddb(2) ) .lt. 1) .or. &
                (abs( orddb(1)-orddb(3) ) .lt. 1) .or. &
                (abs( orddb(1)-orddb(4) ) .lt. 1) .or. &
                (abs( orddb(2)-orddb(3) ) .lt. 1) .or. &
                (abs( orddb(2)-orddb(4) ) .lt. 1) .or. &
                (abs( orddb(3)-orddb(4) ) .lt. 1) )

                orddb(1) = floor((inst%npol-1)*drand(seed)) + 1
                orddb(2) = floor((inst%npol-1)*drand(seed)) + 1
                orddb(3) = floor((inst%npol-1)*drand(seed)) + 1
                orddb(4) = floor((inst%npol-1)*drand(seed)) + 1
            end do

            do i = 1,3
                do j = i+1,4
                    if ( orddb(j) .lt. orddb(i) ) then
                        call dswapi(orddb(j),orddb(i))
                    end if
                end do  
            end do
            ! Apply the Double-Bridge Move
            call DoubleBridgeMove(inst%npol,tour,newtour,x,newx,cost,newcost,&
            orddb(1),orddb(2),orddb(3),orddb(4))
            ! OVERWRITE the current arrays so that the NEXT double-bridge 
            ! move in the loop is applied to this newly perturbed structure.
            tour = newtour
            x = newx
            cost = newcost
        end do

        call BCD(inst,count,tour,x,cost)

    end subroutine PerturbDB

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine VND(inst,param,count,tour,x,cost,alcallbcd,vnd_type)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(parameter_type), intent(inout) :: param
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        integer, intent(in) :: vnd_type
        logical, intent(in) :: alcallbcd
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine must apply the Variable Neighborhood Descent
        ! metaheuristic.

        ! LOCAL SCALARS
        integer :: i,j,k
        real(kind=8) :: barcost,hatcost
        real(kind=8), parameter :: macheps12 = sqrt( epsilon( 1.0d0 ) )

        ! LOCAL ARRAYS
        integer :: bartour(inst%npol),hatour(inst%npol),neigvec(param%jmax)
        real(kind=8) :: xbar(2,inst%npol),xhat(2,inst%npol),privec(param%jmax)

        count%vndcal = count%vndcal+1

        ! =========================================================
        ! NEIGHBORHOOD ORDERING CONFIGURATION
        !
        ! CONVENTION: 0 = fixed order, 1 = random order.
        !
        ! A value outside {0,1} leaves neigvec undefined and the VND then
        ! searches nothing at all, silently. inputdata rejects it up front.
        ! =========================================================
        if ( vnd_type .eq. 0 ) then
            ! Fixed/Sequential Order
            do k = 1, param%jmax
                neigvec(k) = k
            end do
        else if ( vnd_type .eq. 1 ) then
            ! Completely Random Order (Uniform Shuffle)
            ! Initialize all neighborhoods with the exact same baseline priority
            do k = 1, param%jmax
                privec(k) = drand(param%seed)
                neigvec(k) = k
            end do
            ! Sort the neighborhoods descending based strictly on the random draw
            do i = 1, param%jmax - 1
                do k = i + 1, param%jmax
                    if ( privec(k) .gt. privec(i) ) then
                        call dswapr(privec(k),privec(i))    ! Reorders the neighborhoods choice according to the priority vector
                        call dswapi(neigvec(k),neigvec(i))  ! Higher priorities take precedence
                    end if
                end do  
            end do
        end if

        ! =========================================================
        ! VARIABLE NEIGHBORHOOD DESCENT
        ! =========================================================
        bartour = tour
        xbar = x
        barcost = cost
        
        j = param%jmin

        do while ( j .le. param%jmax )
            hatour(1:inst%npol) = bartour(1:inst%npol)
            xhat = xbar
            hatcost = barcost

            call NeighborhoodSearch(inst,param,count,neigvec(j),hatour,xhat,hatcost,alcallbcd)

            if ( .not. all( hatour(1:inst%npol) .eq. bartour(1:inst%npol) ) .and. &
            hatcost .le. barcost - macheps12 * max( 1.0d0, abs(barcost) ) ) then
                bartour = hatour
                xbar = xhat
                barcost = hatcost
                ! Results table
                if ( barcost .lt. count%costils - macheps12 * max( 1.0d0, abs(count%costils) ) ) then
                    count%costils = barcost
                    call cpu_time(count%finish)
                    count%bestime = count%finish - count%start
                    count%bestilsiter = count%ilsiter
                    if ( tuning ) then
                        call write_incumbent(inst,count%costils)
                    else
                        count%gapils = 100 * ( ( count%costils*inst%xymax - inst%gtspopt ) / inst%gtspopt )
                        write(1010,*) count%bestime,count%costils,count%costils*inst%xymax,count%gapils,&
                        count%bestilsiter,count%bestime,count%ilsiter,count%vndcal,count%nscal,neigvec(j),&
                        count%hcalls,count%twoptcall,count%treeoptcall,count%swapcall,count%insercall,&
                        count%dbcall,count%relocall,count%bscall,count%gutincall
                        flush(1010)
                        call write_benchmark_row(inst,param,count,count%costils,'partial',bartour)
                        call write_solution_file(inst,param,bartour,xbar,count%costils)
                    end if
                end if
                ! Step back to the first neighborhood index upon finding a local improvement
                j = param%jmin
            else
                j = j+1
            end if
        end do

        tour = bartour
        x = xbar
        cost = barcost

    end subroutine VND

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine ILS(inst,param,count,tour,x,cost)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(inout) :: inst
        type(parameter_type), intent(inout) :: param
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        real(kind=8), intent(inout) :: cost
        
        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(inst%npol)
        real(kind=8), intent(inout) :: x(2,inst%npol) 

        ! This routine must apply the Iterated Local Search metaheuristic.

        ! PARAMETERS
        real(kind=8), parameter :: macheps12 = sqrt( epsilon( 1.0d0 ) )

        ! LOCAL SCALARS
        logical :: alcallbcd
        integer :: ell,noimprov,inipol
        real(kind=8) :: eta0
        real(kind=8) :: bestcost,hatcost,acost,localcost,time
        
        ! LOCAL ARRAYS
        integer :: bestour(inst%npol),hatour(inst%npol),atour(inst%npol),localtour(inst%npol)
        real(kind=8) :: xbest(2,inst%npol),xhat(2,inst%npol),xatual(2,inst%npol)

        count%maxbcdcic = 3

        alcallbcd = .true.
        call VND(inst,param,count,tour,x,cost,alcallbcd,param%vnd_type)

        count%maxbcdcic = 200
        call BCD(inst,count,tour,x,cost)
        count%maxbcdcic = 3

        ! Resynchronizes the incrementally updated cost with a single O(npol)
        ! evaluation, avoiding the accumulation of rounding errors of the deltas
        call evalf(inst%npol,x,cost)

        ! Results table
        if ( cost .lt. count%costils - macheps12 * max( 1.0d0, abs(count%costils) ) ) then
            count%costils = cost
            call cpu_time(count%finish)
            count%bestime = count%finish - count%start
            time = count%bestime
            count%bestilsiter = count%ilsiter
            if ( tuning ) then
                call write_incumbent(inst,count%costils)
            else
                count%gapils = 100 * ( ( count%costils*inst%xymax - inst%gtspopt ) / inst%gtspopt )
                write(1010,*) count%bestime,count%costils,count%costils*inst%xymax,count%gapils,&
                count%bestilsiter,time,count%ilsiter,count%vndcal,count%nscal,-1,count%hcalls,count%twoptcall,&
                count%treeoptcall,count%swapcall,count%insercall,count%dbcall,count%relocall,count%bscall,&
                count%gutincall
                flush(1010)
                call write_benchmark_row(inst,param,count,count%costils,'partial',tour)
                call write_solution_file(inst,param,tour,x,count%costils)
            end if
        end if

        bestour = tour   ! Stores the best solution - incumbente
        xbest = x
        bestcost = cost

        atour = tour     ! Stores the current solution
        xatual = x
        acost = cost

        localtour = tour
        localcost = cost ! Added to track scalar cost of local optimum

        noimprov = 0     ! Number of times we fall into the same local optimum.
        ell = 0

        ! Initial value of the acceptance threshold. param%eps is updated in
        ! place along the run, so the reheating needs this copy of eta0.
        eta0 = param%eps

        ! count%maxbcdcic = 3

        do while ( ell .lt. param%ell_np_max )
            count%ilsiter = count%ilsiter + 1

            hatour = atour
            xhat = xatual
            hatcost = acost

            if ( noimprov .eq. 3 ) then
                noimprov = 0
                count%nrestnn = count%nrestnn + 1
                inipol = floor( inst%npol * drand(param%seed) ) + 1
                call nn(inst,count,inipol,hatour,xhat,hatcost)
            else
                call PerturbDB(inst,count,hatour,xhat,hatcost,param%seed,param%numdbmoves)
            end if

            call VND(inst,param,count,hatour,xhat,hatcost,alcallbcd,param%vnd_type)

            count%maxbcdcic = 200
            call BCD(inst,count,hatour,xhat,hatcost)
            count%maxbcdcic = 3

            ! Resynchronizes the incrementally updated cost (see comment above)
            call evalf(inst%npol,xhat,hatcost)

            if ( hatcost .le. bestcost - macheps12 * max( 1.0d0, abs(bestcost) ) ) then

                bestour = hatour
                xbest = xhat
                bestcost = hatcost

                ! Results table
                if ( bestcost .lt. count%costils - macheps12 * max( 1.0d0, abs(count%costils) ) ) then
                    count%costils = bestcost
                    call cpu_time(count%finish)
                    count%bestime = count%finish - count%start
                    time = count%bestime
                    count%bestilsiter = count%ilsiter
                    if ( tuning ) then
                        call write_incumbent(inst,count%costils)
                    else
                        count%gapils = 100 * ( ( count%costils*inst%xymax - inst%gtspopt ) / inst%gtspopt )
                        write(1010,*) count%bestime,count%costils,count%costils*inst%xymax,count%gapils,&
                        count%bestilsiter,time,count%ilsiter,count%vndcal,count%nscal,-1,count%hcalls,count%twoptcall,&
                        count%treeoptcall,count%swapcall,count%insercall,count%dbcall,count%relocall,count%bscall,&
                        count%gutincall
                        flush(1010)
                        call write_benchmark_row(inst,param,count,count%costils,'partial',hatour)
                        call write_solution_file(inst,param,hatour,xhat,count%costils)
                    end if
                end if
                
                ell = 0
                noimprov = 0
            else
                ! If the costs are different, the tours CANNOT be the same.
                if ( abs( hatcost - localcost ) .le. macheps12 * max( 1.0d0, abs(localcost) ) ) then
                    if ( all( hatour(1:inst%npol) .eq. localtour(1:inst%npol) ) ) then
                        noimprov = noimprov+1     ! Number of times without improvement
                    end if
                end if
                ell = ell + 1
            end if

            if ( (hatcost .le. acost - macheps12 * max( 1.0d0, abs(acost) )) .or. &
            (hatcost .le. (1.0d0+param%eps)*bestcost) ) then

                atour = hatour
                xatual = xhat
                acost = hatcost

                localtour = atour
                localcost = acost
            end if   

            ! =========================================================
            ! ACCEPTANCE THRESHOLD (eta, held in param%eps). It is updated
            ! from the progress of the search alone - never from the clock
            ! nor from the time limit - so a longer run is the shorter run
            ! continued and the same seed always reproduces the same run.
            !
            ! REDUCTION: eta <- h * eta after every nstag consecutive
            ! iterations that fail to improve the incumbent. The counter is
            ! ell, the very one that stops the loop at ell_np_max, so no
            ! second counter is needed. mod() is used instead of resetting
            ! it: resetting ell here would destroy the stagnation stopping
            ! criterion and every run would last the whole time budget.
            !
            ! REHEATING: once eta falls below etamin the acceptance test
            ! already takes essentially nothing but improvements, so eta
            ! goes back to its initial value and the current solution is
            ! reset to the best one. Without this the search degenerates
            ! into a pure descent on long runs. With h = 1 eta never
            ! decreases and the reheating never fires.
            ! =========================================================
            if ( ell .gt. 0 .and. mod( ell, nstag ) .eq. 0 ) then
                param%eps = param%h * param%eps
                count%netared = count%netared + 1

                if ( param%eps .lt. etamin ) then
                    param%eps = eta0
                    atour     = bestour
                    xatual    = xbest
                    acost     = bestcost
                    localtour = atour
                    localcost = acost
                    count%netareheat = count%netareheat + 1
                end if
            end if

            ! if ( mod( count%ilsiter, 10 ) .eq. 0 .and. count%ilsiter .lt. 50 ) then
            !     count%maxbcdcic = count%maxbcdcic * 3
            ! end if

            ! OPTIMIZATION: this progress line forced one write + flush to disk
            ! PER ITERATION of the ILS, even without improvement. It is now only
            ! written when logprogress = .true. (see module parameters).
            if ( logprogress .and. .not. tuning ) then
                call cpu_time(count%finish)
                time = count%finish - count%start
                write(1010,*) count%bestime,count%costils,count%costils*inst%xymax,count%gapils,&
                count%bestilsiter,time,count%ilsiter,count%vndcal,count%nscal,-2,count%hcalls,count%twoptcall,&
                count%treeoptcall,count%swapcall,count%insercall,count%dbcall,count%relocall,count%bscall,&
                count%gutincall  
                flush(1010)
            end if
        end do

        tour = bestour
        x = xbest
        cost = bestcost

        call cpu_time(count%finish)
        time = count%finish - count%start

        ! This closing line starts with '#', so it is NOT a number: it must not
        ! be the last line of the file irace parses. In calibration mode the
        ! incumbent file is left holding the best cost and nothing else.
        if ( .not. tuning ) then
            write(1010,*) '# ILS solution = ',count%bestime,count%costils,count%costils*inst%xymax,count%gapils,&
            count%bestilsiter,time,count%ilsiter,count%vndcal,count%nscal,-2,count%hcalls,count%twoptcall,&
            count%treeoptcall,count%swapcall,count%insercall,count%dbcall,count%relocall,count%bscall,&
            count%gutincall
            flush(1010)
        end if
    end subroutine ILS

    ! ***************** MOVES (delta evaluation) **********************

    subroutine DoubleBridgeMove(npol,tour,newtour,x,newx,cost,newcost,i,j,k,ell)
        
        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: i,j,k,ell,npol
        real(kind=8), intent(in) :: cost
        real(kind=8), intent(out) :: newcost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(npol) 
        integer, intent(out) :: newtour(npol)
        real(kind=8), intent(in) :: x(2,npol)
        real(kind=8), intent(out) :: newx(2,npol)
        
        ! This routine must apply a double-bridge move, which remove the edges
        ! (i,i+1), (j,j+1), (k,k+1) and (ell,ell+1), and and inserts the edges
        ! (i,k+1), (ell,j+1), (k,i+1) and (j, ell+1). Note: i < j < k < ell.
        ! OPTIMIZATION: the cost of the new solution is obtained from the cost of
        ! the current solution by subtracting the 4 broken edges and adding the 4
        ! new ones (no call to evalf).

        ! LOCAL SCALARS
        integer :: ellp
        real(kind=8) :: brokencost,addedcost

        newtour(1:i) = tour(1:i)     
        newtour(i+1:i+ell-k) = tour(k+1:ell)
        newtour(i+ell-k+1:i+ell-j) = tour(j+1:k)
        newtour(i+ell-j+1:ell) = tour(i+1:j)
        newtour(ell+1:npol) = tour(ell+1:npol)

        newx(1:2,1:i) = x(1:2,1:i) 
        newx(1:2,i+1:i+ell-k) = x(1:2,k+1:ell)
        newx(1:2,i+ell-k+1:i+ell-j) = x(1:2,j+1:k)
        newx(1:2,i+ell-j+1:ell) = x(1:2,i+1:j)
        newx(1:2,ell+1:npol) = x(1:2,ell+1:npol)

        ! Cyclic wrap-around (only ell can be equal to npol, since i < j < k < ell)
        ellp = merge(1, ell+1, ell .eq. npol)

        ! --- Cost of the 4 BROKEN edges ---
        brokencost = edge(i,i+1) + edge(j,j+1) + edge(k,k+1) + edge(ell,ellp)

        ! --- Cost of the 4 ADDED edges ---
        addedcost = edge(i,k+1) + edge(ell,j+1) + edge(k,i+1) + edge(j,ellp)

        newcost = cost + ( addedcost - brokencost )

        ! call evalf(npol,newx,testcost)
        ! if ( abs( testcost - newcost ) .ge. sqrt( epsilon( 1.0d0 ) ) ) then
        !     write(*,*) 'ALGO ERRADO AO CALCULAR NEWCOST DOUBLEBRIDGEMOVE'
        ! end if

        contains

            ! Length of the current tour edge between positions a and b
            pure function edge(a,b) result(dab)
                integer, intent(in) :: a,b
                real(kind=8) :: dab,dx,dy
                dx = x(1,a) - x(1,b)
                dy = x(2,a) - x(2,b)
                dab = sqrt( dx * dx + dy * dy )
            end function edge

    end subroutine DoubleBridgeMove

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    real(kind=8)  function cost_d(npol,i,j,x,edgelen)

        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: npol,i,j 

        ! ARRAY ARGUMENTS
        real(kind=8), intent(in) :: x(2,npol),edgelen(npol) 

        ! This function is used in the DoubleBridgeN routine.
        ! OPTIMIZATION: the lengths of the current edges (i,i+1) and (j,j+1) are 
        ! read from the precomputed vector edgelen (2 norm2 calls saved).

        ! LOCAL SCALAR
        integer :: inext,jnext

        ! Safely handle cyclic wrap-around
        inext = merge(1, i+1, i == npol)
        jnext = merge(1, j+1, j == npol)

        cost_d = ( norm2( x(1:2,i) - x(1:2,jnext) ) + norm2( x(1:2,inext) - x(1:2,j) ) ) &
        - ( edgelen(i) + edgelen(j) )

        return

    end function cost_d

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    real(kind=8)  function cost_c(npol,i,j,x,edgelen)

        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: npol,i,j 

        ! ARRAY ARGUMENTS
        real(kind=8), intent(in) :: x(2,npol),edgelen(npol) 

        ! This function is used in the DoubleBridgeN routine.
        ! OPTIMIZATION: the lengths of the current edges (i,i+1) and (j,j+1) are 
        ! read from the precomputed vector edgelen (2 norm2 calls saved).

        ! LOCAL SCALAR
        integer :: inext,jnext

        ! Safely handle cyclic wrap-around
        inext = merge(1, i+1, i == npol)
        jnext = merge(1, j+1, j == npol)

        cost_c = ( norm2( x(1:2,i) - x(1:2,j) ) + norm2( x(1:2,inext) - x(1:2,jnext) ) ) &
        - ( edgelen(i) + edgelen(j) )

        return

    end function cost_c

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine Type2Move(npol,tour,newtour,x,newx,cost,newcost,i,j,k,ell,typpe)
        
        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: i,j,k,ell,npol,typpe
        real(kind=8), intent(in) :: cost
        real(kind=8), intent(out) :: newcost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(npol) 
        integer, intent(out) :: newtour(npol)
        real(kind=8), intent(in) :: x(2,npol)
        real(kind=8), intent(out) :: newx(2,npol)
        
        ! This routine applies a Glover Type 2 move (Twisted Bridge).
        ! typpe = 2: Reverse segments C and D
        ! typpe = 3: Reverse segments B and C
        ! OPTIMIZATION: the cost of the new solution is obtained from the cost of
        ! the current solution by subtracting the 4 broken edges and adding the 4
        ! new ones (no call to evalf).

        ! LOCAL SCALARS
        integer :: ellp
        real(kind=8) :: brokencost,addedcost

        ! Cyclic wrap-around (only ell can be equal to npol, since i < j < k < ell)
        ellp = merge(1, ell+1, ell .eq. npol)

        ! --- Cost of the 4 BROKEN edges (the same for both move types) ---
        brokencost = edge(i,i+1) + edge(j,j+1) + edge(k,k+1) + edge(ell,ellp)

        ! Safety: typpe must be 2 or 3 (otherwise the move is a no-op with delta 0)
        addedcost = brokencost

        if ( typpe .eq. 2 ) then
            newtour(1:i) = tour(1:i)
            newtour(i+1:i+k-j) = tour(k:j+1:-1)       ! C reversed
            newtour(i+k-j+1:i+ell-j) = tour(ell:k+1:-1) ! D reversed
            newtour(i+ell-j+1:ell) = tour(i+1:j)      ! B forward
            newtour(ell+1:npol) = tour(ell+1:npol)

            newx(1:2,1:i) = x(1:2,1:i) 
            newx(1:2,i+1:i+k-j) = x(1:2,k:j+1:-1)
            newx(1:2,i+k-j+1:i+ell-j) = x(1:2,ell:k+1:-1)
            newx(1:2,i+ell-j+1:ell) = x(1:2,i+1:j)
            newx(1:2,ell+1:npol) = x(1:2,ell+1:npol)

            ! --- Cost of the 4 ADDED edges ---
            addedcost = edge(i,k) + edge(j+1,ell) + edge(k+1,i+1) + edge(j,ellp)

        else if (typpe .eq. 3) then
            newtour(1:i) = tour(1:i)
            newtour(i+1:i+ell-k) = tour(k+1:ell)      ! D forward
            newtour(i+ell-k+1:i+ell-k+j-i) = tour(j:i+1:-1) ! B reversed
            newtour(i+ell-k+j-i+1:ell) = tour(k:j+1:-1)     ! C reversed
            newtour(ell+1:npol) = tour(ell+1:npol)

            newx(1:2,1:i) = x(1:2,1:i) 
            newx(1:2,i+1:i+ell-k) = x(1:2,k+1:ell)
            newx(1:2,i+ell-k+1:i+ell-k+j-i) = x(1:2,j:i+1:-1)
            newx(1:2,i+ell-k+j-i+1:ell) = x(1:2,k:j+1:-1)
            newx(1:2,ell+1:npol) = x(1:2,ell+1:npol)

            ! --- Cost of the 4 ADDED edges ---
            addedcost = edge(i,k+1) + edge(ell,j) + edge(i+1,k) + edge(j+1,ellp)
        end if

        newcost = cost + ( addedcost - brokencost )

        ! call evalf(npol,newx,testcost)
        ! if ( abs( testcost - newcost ) .ge. sqrt( epsilon( 1.0d0 ) ) ) then
        !     write(*,*) 'ALGO ERRADO AO CALCULAR NEWCOST TYPE2MOVE'
        ! end if

        contains

            ! Length of the current tour edge between positions a and b
            pure function edge(a,b) result(dab)
                integer, intent(in) :: a,b
                real(kind=8) :: dab,dx,dy
                dx = x(1,a) - x(1,b)
                dy = x(2,a) - x(2,b)
                dab = sqrt( dx * dx + dy * dy )
            end function edge

    end subroutine Type2Move

    ! *****************************************************************
    ! *****************************************************************

    subroutine SwapMove(npol,tour,newtour,x,newx,cost,newcost,i,j)
        
        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: i,j,npol
        real(kind=8), intent(in) :: cost
        real(kind=8), intent(out) :: newcost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(npol) 
        integer, intent(out) :: newtour(npol)
        real(kind=8), intent(in) :: x(2,npol)
        real(kind=8), intent(out) :: newx(2,npol)
        
        ! This routine must apply the swap move, which swaps 
        ! positions i and j, with j >= i+2.
        ! OPTIMIZATION: the cost of the new solution is obtained from the cost of
        ! the current solution by subtracting the broken edges and adding the new
        ! ones (no call to evalf).

        ! LOCAL SCALARS
        integer :: im,ip,jm,jp
        real(kind=8) :: brokencost,addedcost

        newtour = tour   
        newtour(i) = tour(j) 
        newtour(j) = tour(i) 

        newx = x 
        newx(1:2,i) = x(1:2,j)
        newx(1:2,j) = x(1:2,i)

        ! Cyclic neighbors of positions i and j (i <= npol-2 and j >= i+2 >= 3)
        im = merge(npol, i-1, i .eq. 1)
        ip = i + 1
        jm = j - 1
        jp = merge(1, j+1, j .eq. npol)

        if ( i .eq. 1 .and. j .eq. npol ) then
            ! --- CYCLIC OVERLAP PROTECTION ---
            ! i and j are adjacent in the cycle through the edge (npol,1):
            ! only 2 edges are broken and 2 are added
            brokencost = edge(jm,j) + edge(i,ip)
            addedcost  = edge(jm,i) + edge(j,ip)
        else
            ! General case: 4 edges broken, 4 added. When j = i+2 the terms of 
            ! the edges incident to the middle position cancel each other out.
            brokencost = edge(im,i) + edge(i,ip) + edge(jm,j) + edge(j,jp)
            addedcost  = edge(im,j) + edge(j,ip) + edge(jm,i) + edge(i,jp)
        end if

        newcost = cost + ( addedcost - brokencost )

        ! call evalf(npol,newx,testcost)
        ! if ( abs( testcost - newcost ) .ge. sqrt( epsilon( 1.0d0 ) ) ) then
        !     write(*,*) 'ALGO ERRADO AO CALCULAR NEWCOST SWAPMOVE'
        ! end if

        contains

            ! Length of the current tour edge between positions a and b
            pure function edge(a,b) result(dab)
                integer, intent(in) :: a,b
                real(kind=8) :: dab,dx,dy
                dx = x(1,a) - x(1,b)
                dy = x(2,a) - x(2,b)
                dab = sqrt( dx * dx + dy * dy )
            end function edge

    end subroutine SwapMove

    ! *****************************************************************
    ! *****************************************************************

    subroutine TwoOptMove(npol,tour,newtour,x,newx,cost,newcost,i,j)
        
        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: i,j,npol
        real(kind=8), intent(in) :: cost
        real(kind=8), intent(out) :: newcost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(npol) 
        integer, intent(out) :: newtour(npol)
        real(kind=8), intent(in) :: x(2,npol)
        real(kind=8), intent(out) :: newx(2,npol)
        
        ! This routine must apply a 2-opt move between the 
        ! edges (i, i+1) and (j, j+1).
        ! OPTIMIZATION: the cost of the new solution is obtained from the cost of
        ! the current solution by subtracting the 2 broken edges and adding the 2
        ! new ones (no call to evalf).

        ! LOCAL SCALARS
        integer :: ip,jp
        real(kind=8) :: brokencost,addedcost

        newtour(1:i) = tour(1:i)     
        newtour(i+1:j) = tour(j:i+1:-1)
        newtour(j+1:npol) = tour(j+1:npol)

        newx(1:2,1:i) = x(1:2,1:i) 
        newx(1:2,i+1:j) = x(1:2,j:i+1:-1)
        newx(1:2,j+1:npol) = x(1:2,j+1:npol)

        ! Cyclic wrap-around (i <= npol-2)
        ip = i + 1
        jp = merge(1, j+1, j .eq. npol)

        ! Broken edges: (i,i+1) and (j,j+1). Added edges: (i,j) and (i+1,j+1).
        brokencost = edge(i,ip) + edge(j,jp)
        addedcost  = edge(i,j)  + edge(ip,jp)

        newcost = cost + ( addedcost - brokencost )

        ! call evalf(npol,newx,testcost)
        ! if ( abs( testcost - newcost ) .ge. sqrt( epsilon( 1.0d0 ) ) ) then
        !     write(*,*) 'ALGO ERRADO AO CALCULAR NEWCOST TWOOPTMOVE'
        ! end if

        contains

            ! Length of the current tour edge between positions a and b
            pure function edge(a,b) result(dab)
                integer, intent(in) :: a,b
                real(kind=8) :: dab,dx,dy
                dx = x(1,a) - x(1,b)
                dy = x(2,a) - x(2,b)
                dab = sqrt( dx * dx + dy * dy )
            end function edge

    end subroutine TwoOptMove

    ! *****************************************************************
    ! *****************************************************************

    subroutine InsertMove(npol,tour,newtour,x,newx,cost,newcost,i,j)
        
        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: i,j,npol
        real(kind=8), intent(in) :: cost
        real(kind=8), intent(out) :: newcost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(npol) 
        integer, intent(out) :: newtour(npol)
        real(kind=8), intent(in) :: x(2,npol)
        real(kind=8), intent(out) :: newx(2,npol)
        
        ! This routine must apply the relocation move, which removes
        ! the element from position i and inserts it at position j.
        ! OPTIMIZATION: the cost of the new solution is obtained from the cost of
        ! the current solution by subtracting the 3 broken edges and adding the 3
        ! new ones (no call to evalf).

        ! LOCAL SCALARS
        integer :: im,ip,jm,jp
        real(kind=8) :: brokencost,addedcost

        if ( j .lt. i ) then
            newtour(1:j-1) = tour(1:j-1)     
            newtour(j) = tour(i)
            newtour(j+1:i) = tour(j:i-1)
            newtour(i+1:npol) = tour(i+1:npol)

            newx(1:2,1:j-1) = x(1:2,1:j-1) 
            newx(1:2,j) = x(1:2,i)
            newx(1:2,j+1:i) = x(1:2,j:i-1)
            newx(1:2,i+1:npol) = x(1:2,i+1:npol)
        else
            newtour(1:i-1) = tour(1:i-1)     
            newtour(i:j-1) = tour(i+1:j)
            newtour(j) = tour(i)
            newtour(j+1:npol) = tour(j+1:npol)

            newx(1:2,1:i-1) = x(1:2,1:i-1) 
            newx(1:2,i:j-1) = x(1:2,i+1:j)
            newx(1:2,j) = x(1:2,i)
            newx(1:2,j+1:npol) = x(1:2,j+1:npol)
        end if

        if ( ( i .eq. 1 .and. j .eq. npol ) .or. ( i .eq. npol .and. j .eq. 1 ) ) then
            ! --- CYCLIC OVERLAP PROTECTION ---
            ! Moving the first element to the last position (or vice versa) is a
            ! pure rotation of the cyclic tour: the cost does not change
            newcost = cost
        else if ( j .gt. i ) then
            ! Cyclic neighbors (i < j <= npol implies i+1 <= npol)
            im = merge(npol, i-1, i .eq. 1)
            ip = i + 1
            jp = merge(1, j+1, j .eq. npol)
            ! Broken: (i-1,i),(i,i+1),(j,j+1). Added: (i-1,i+1),(j,i),(i,j+1).
            ! When j = i+1 the terms edge(i,ip) and edge(j,i) cancel each other out.
            brokencost = edge(im,i) + edge(i,ip) + edge(j,jp)
            addedcost  = edge(im,ip) + edge(j,i) + edge(i,jp)
            newcost = cost + ( addedcost - brokencost )
        else
            ! Cyclic neighbors (j < i <= npol implies i-1 >= 1)
            jm = merge(npol, j-1, j .eq. 1)
            im = i - 1
            ip = merge(1, i+1, i .eq. npol)
            ! Broken: (j-1,j),(i-1,i),(i,i+1). Added: (j-1,i),(i,j),(i-1,i+1).
            ! When j = i-1 the terms edge(jm,j) and edge(i,j) cancel each other out.
            brokencost = edge(jm,j) + edge(im,i) + edge(i,ip)
            addedcost  = edge(jm,i) + edge(i,j) + edge(im,ip)
            newcost = cost + ( addedcost - brokencost )
        end if

        ! call evalf(npol,newx,testcost)
        ! if ( abs( testcost - newcost ) .ge. sqrt( epsilon( 1.0d0 ) ) ) then
        !     write(*,*) 'ALGO ERRADO AO CALCULAR NEWCOST INSERTMOVE'
        ! end if

        contains

            ! Length of the current tour edge between positions a and b
            pure function edge(a,b) result(dab)
                integer, intent(in) :: a,b
                real(kind=8) :: dab,dx,dy
                dx = x(1,a) - x(1,b)
                dy = x(2,a) - x(2,b)
                dab = sqrt( dx * dx + dy * dy )
            end function edge

    end subroutine InsertMove

    ! *****************************************************************
    ! *****************************************************************
    ! Avoids calling evalf on every move: the cost is updated from the
    ! edges that the move breaks and adds.
    subroutine StringMove(npol,tour,newtour,x,newx,cost,newcost,i,k,j,string,strlen,inverter)
        
        implicit none

        ! SCALAR ARGUMENTS
        logical, intent(in) :: inverter
        integer, intent(in) :: npol,i,k,j,strlen
        real(kind=8), intent(in) :: cost
        real(kind=8), intent(out) :: newcost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(npol) 
        integer, intent(out) :: newtour(npol)
        real(kind=8), intent(in) :: x(2,npol),string(2,strlen)
        real(kind=8), intent(out) :: newx(2,npol)
        
        ! This routine must apply a string relocation move, which 
        ! removes the string of length k+1 from positions i to i+k+1,
        ! and inserts it between the elements of positions j and j+1.

        ! LOCAL SCALARS
        integer :: leftout,rightout,leftin,rightin,strstart,strend
        real(kind=8) :: brokencost,addedcost,dx,dy,delta!,testcost

        ! EXTERNAL SUBROUTINES
        ! external :: evalf

        if ( j .lt. i ) then
            newtour(1:j) = tour(1:j)    
            newx(1:2,1:j) = x(1:2,1:j) 
            if ( inverter ) then
                newtour(j+1:j+k+1) = tour(i+k:i:-1)
                newx(1:2,j+1:j+k+1) = string(1:2,k+1:1:-1)
            else
                newtour(j+1:j+k+1) = tour(i:i+k)
                newx(1:2,j+1:j+k+1) = string(1:2,1:k+1)
            end if
            newtour(j+k+2:i+k) = tour(j+1:i-1)
            newtour(i+k+1:npol) = tour(i+k+1:npol)
            newx(1:2,j+k+2:i+k) = x(1:2,j+1:i-1)
            newx(1:2,i+k+1:npol) = x(1:2,i+k+1:npol)
        else
            newtour(1:i-1) = tour(1:i-1)     
            newtour(i:j-k-1) = tour(i+k+1:j)
            newx(1:2,1:i-1) = x(1:2,1:i-1) 
            newx(1:2,i:j-k-1) = x(1:2,i+k+1:j)
            if ( inverter ) then
                newtour(j-k:j) = tour(i+k:i:-1)
                newx(1:2,j-k:j) = string(1:2,k+1:1:-1)
            else
                newtour(j-k:j) = tour(i:i+k)
                newx(1:2,j-k:j) = string(1:2,1:k+1)
            end if
            newtour(j+1:npol) = tour(j+1:npol)
            newx(1:2,j+1:npol) = x(1:2,j+1:npol)
        end if

        leftout  = merge(npol, i - 1, i == 1)
        rightout = merge(1, i + k + 1, i + k == npol)
        strstart = i
        strend   = i + k
        leftin   = j
        rightin  = merge(1, j + 1, j == npol)

        ! --- CYCLIC OVERLAP PROTECTION ---
        ! If the insertion point matches the exact extraction boundary, this is 
        ! an in-place move. The 3-edge swap formula fails here due to edge duplication.
        if (leftin .eq. leftout .or. leftin .eq. strend) then
            if (.not. inverter) then
                ! Moving a block to its exact same position changes nothing.
                delta = 0.0d0
            else
                ! Reversing the block in-place is a 2-opt move (2 edges broken, 2 added)
                dx = x(1,leftout) - x(1,strstart) 
                dy = x(2,leftout) - x(2,strstart)
                brokencost = sqrt(dx*dx + dy*dy)
                dx = x(1,strend) - x(1,rightout) 
                dy = x(2,strend) - x(2,rightout)
                brokencost = brokencost + sqrt(dx*dx + dy*dy)
                dx = x(1,leftout) - x(1,strend)   
                dy = x(2,leftout) - x(2,strend)
                addedcost = sqrt(dx*dx + dy*dy)
                dx = x(1,strstart) - x(1,rightout) 
                dy = x(2,strstart) - x(2,rightout)
                addedcost = addedcost + sqrt(dx*dx + dy*dy)
                delta = addedcost - brokencost
            end if
            newcost = cost + delta
            return
        end if

        ! --- Calculate cost of 3 BROKEN edges ---
        dx = x(1,leftout) - x(1,strstart) 
        dy = x(2,leftout) - x(2,strstart)
        brokencost = sqrt( dx * dx + dy * dy )
        dx = x(1,strend) - x(1,rightout)
        dy = x(2,strend) - x(2,rightout)
        brokencost = brokencost + sqrt( dx * dx + dy * dy )
        dx = x(1,leftin) - x(1,rightin)
        dy = x(2,leftin) - x(2,rightin)
        brokencost = brokencost + sqrt( dx * dx + dy * dy )

        ! --- Calculate cost of 3 ADDED edges ---
        ! Edge 1: Stitching the gap where the string used to be
        dx = x(1,leftout) - x(1,rightout)
        dy = x(2,leftout) - x(2,rightout)
        addedcost = sqrt( dx * dx + dy * dy )

        if (.not. inverter) then
            ! Connecting the string in its normal order
            dx = x(1,leftin) - x(1,strstart)
            dy = x(2,leftin) - x(2,strstart)
            addedcost = addedcost + sqrt( dx * dx + dy * dy )
            dx = x(1,strend) - x(1,rightin)
            dy = x(2,strend) - x(2,rightin)
            addedcost = addedcost + sqrt( dx * dx + dy * dy )
        else
            ! Connecting the string in reverse order
            dx = x(1,leftin) - x(1,strend)
            dy = x(2,leftin) - x(2,strend)
            addedcost = addedcost + sqrt( dx * dx + dy * dy )
            dx = x(1,strstart) - x(1,rightin)
            dy = x(2,strstart) - x(2,rightin)
            addedcost = addedcost + sqrt( dx * dx + dy * dy )
        end if

        delta = addedcost - brokencost
        newcost = cost + delta
        ! call evalf(npol,newx,newcost)
        ! if ( abs( testcost - newcost ) .ge. macheps12 ) then
        !     write(*,*) 'ALGO ERRADO AO CALCULAR NEWCOST STRINGRELOC'
        !     write(*,*) 'testcost - newcost = ',testcost - newcost
        !     write(*,*) 'newcost = ',newcost
        !     write(*,*) 'testcost = ',testcost
        !     stop
        ! end if

    end subroutine StringMove

end module metaheuristic
