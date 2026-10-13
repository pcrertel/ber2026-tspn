! =====================================================================
!  program ils_tspn -> main program
! =====================================================================
program ils_tspn 

    use instance
    use metaheuristic

    implicit none

    ! LOCAL SCALARS
    logical :: normalize
    integer :: allocerr,inipol,ninc,k
    real(kind=8) :: ccost,bestcost,tnow
    type(instance_type) :: inst
    type(parameter_type) :: param
    type(counter_type) :: count

    ! LOCAL ARRAYS
    integer, allocatable :: ctour(:),besttour(:)
    real(kind=8), allocatable :: csol(:,:),bestsol(:,:)
    ! Improvements of the multi-start construction (time, cost, nn calls),
    ! kept in memory and written to the incumbent file after the loop
    integer, allocatable :: inchc(:)
    real(kind=8), allocatable :: inctime(:),inccost(:)

    normalize = .true.
    call inputdata(inst,count,param,normalize)

    ! Loads the best-known GTSP+BCD tour ONCE (canonicalized) into inst.
    ! Used by write_benchmark_row to fill the 'tour_match' column. No disk
    ! I/O happens during the search after this call. Skipped in calibration
    ! mode, where the benchmark table is not written.
    if ( .not. tuning ) call load_reference_tour(inst)

    allocate(ctour(inst%npol),csol(2,inst%npol),&
    besttour(inst%npol),bestsol(2,inst%npol),stat=allocerr)

    if ( allocerr .ne. 0 ) then
        write(*,*) 'Allocation error - Main.'
        stop
    end if

    ! -----------------------------------------------------------------
    ! START OF THE MEASURED INTERVAL.
    !
    ! The clock starts HERE, before the construction. The initial solution is
    ! built by the multi-start below, which costs a few seconds on the largest
    ! instances; leaving it outside the measured interval would understate the
    ! cost of a run by exactly that amount. Every CPU time this program
    ! reports therefore includes the construction.
    ! -----------------------------------------------------------------
    call cpu_time(count%start)

    ! -----------------------------------------------------------------
    ! Initial solution: deterministic multi-start Nearest Neighbor.
    !
    ! nn is run once from EACH polygon inipol = 1..npol and the best of the
    ! npol constructions is kept. nn itself finishes with a full BCD, so every
    ! candidate is a solution with optimized visit points, not a raw greedy
    ! tour.
    ! Building the initial solution here, rather than reading it from a file,
    ! is what makes a run reproducible from the instance and the seed alone.
    !
    ! It is DETERMINISTIC - it does not touch the random stream - so it costs
    ! no variance at all: every configuration racing on an instance starts from
    ! the very same solution, and the cost below is a constant offset charged
    ! equally to all of them.
    !
    ! COST. Projected over the 80 training instances from timings of the
    ! previous initial-solution files, one construction runs in about
    ! 2.2e-5 * npol^1.5 seconds, so the whole multi-start is ~0.9 s on average
    ! (0.3% of a 300 s budget) and ~2.2 s on the npol = 100 instances (0.7%);
    ! the measured scatter around that fit is a factor of ~3, which puts the
    ! plausible worst case near 7 s (2.2%). That is why the loop below is the
    ! plain one and not a cheaper scan with a capped BCD. The projection is
    ! worth checking once against reality: count%bestime, written on the first
    ! line of the sweep's incumbent file, is now exactly this construction time.
    ! -----------------------------------------------------------------
    !
    ! Every time a construction improves the best one so far, its CPU time and
    ! cost are recorded (in memory, so that no disk I/O happens inside the
    ! measured loop) and written after the loop to the incumbent file with
    ! ORIGIN = -3, before the usual -2 line of the chosen initial solution.
    ! This lets the convergence plots start at t = 0 instead of at the end
    ! of the construction.
    ! -----------------------------------------------------------------
    allocate(inctime(inst%npol),inccost(inst%npol),inchc(inst%npol))
    ninc = 0
    bestcost = huge( 1.0d0 )
    do inipol = 1, inst%npol
        call nn(inst,count,inipol,ctour,csol,ccost)
        if ( ccost .lt. bestcost ) then
            bestcost = ccost
            besttour = ctour
            bestsol  = csol
            call cpu_time(tnow)
            ninc = ninc + 1
            inctime(ninc) = tnow - count%start
            inccost(ninc) = ccost
            inchc(ninc)   = count%hcalls
        end if
    end do

    ctour = besttour
    csol  = bestsol
    ccost = bestcost

    count%costils = ccost

    ! Time at which the incumbent was found. It is not zero: the construction
    ! is inside the measured interval.
    call cpu_time(count%finish)
    count%bestime = count%finish - count%start

    if ( tuning ) then

        ! CALIBRATION MODE: the incumbent file carries the LITERAL name given
        ! on stdin (irace makes it unique per experiment) and holds a single
        ! number. Seeded here with the cost of the best NN solution, so the
        ! file already exists even if the run is killed before any improvement.
        call write_incumbent(inst,count%costils)

    else

        count%gapils = 100 * ( ( count%costils*inst%xymax - inst%gtspopt ) / inst%gtspopt )

        open(unit=1010,file=trim(adjustl(inst%incumbfile))//trim(basename(inst%filename)))
        ! Improvements of the multi-start (ORIGIN = -3): same 19 fields, with
        ! the ILS counters still zero and the number of nn calls in field 11
        do k = 1, ninc
            write(1010,*) inctime(k),inccost(k),inccost(k)*inst%xymax,&
            100 * ( ( inccost(k)*inst%xymax - inst%gtspopt ) / inst%gtspopt ),&
            0,inctime(k),0,0,0,-3,inchc(k),0,0,0,0,0,0,0,0
        end do
        ! write(1010,*) time,cost-normal,cost-orig,gap,ilsiter,vndcalls,neighb-searchs,neigh-that-improve-sol,HC-calls
        write(1010,*) count%bestime,count%costils,count%costils*inst%xymax,count%gapils,&
        count%bestilsiter,count%bestime,count%ilsiter,count%vndcal,count%nscal,-2,count%hcalls,count%twoptcall,&
        count%treeoptcall,count%swapcall,count%insercall,count%dbcall,count%relocall,count%bscall,&
        count%gutincall
        ! Force the write to reach the disk now
        flush(1010)

        ! Initial solution (tour and visit points), for the figures:
        ! ils-toursol/ils-init-<instance>-seed<N>-<version>.dat
        call write_solution_file(inst,param,ctour,csol,ccost,'ils-init-')

        ! Benchmark row of the initial solution. Rows are otherwise written
        ! only when the ILS improves the incumbent or ends by stagnation, so
        ! without this one a run killed by the time limit before any
        ! improvement would leave no row at all. Any later row replaces it.
        call write_benchmark_row(inst,param,count,ccost,'partial',ctour)

    end if

    ! ILS metaheuristic. The clock is already running - see the comment above
    ! the multi-start; do NOT reset count%start here.
    call ILS(inst,param,count,ctour,csol,ccost)

    if ( tuning ) then

        ! Final value, in case the last improvement happened inside a code path
        ! that did not write (it always does, but this costs nothing and makes
        ! the contract with irace unconditional).
        call write_incumbent(inst,ccost)

    else

        ! --------------------------------------------------------------
        ! Final write, mirroring the per-improvement writes done DURING the
        ! search (so runs killed by the timeout keep their best solution and
        ! their benchmark row). write_solution_file and write_benchmark_row are
        ! self-contained: each canonicalizes its own copy of the tour, so the
        ! working arrays are not modified here.
        ! --------------------------------------------------------------
        call write_solution_file(inst,param,ctour,csol,ccost)

        ! Appends one summary row (cost, gap, times, counters, tour_match) to
        ! the benchmark table tables/benchmark_summary.csv
        call write_benchmark_row(inst,param,count,ccost,'final',ctour)

        close(1010)

    end if

    if ( allocated(inst%reftour) ) deallocate(inst%reftour)
    deallocate(inst%nvp,inst%vcoor,inst%barycenters,inst%bbox,inst%cand,inst%canddist,&
    ctour,csol,besttour,bestsol,inctime,inccost,inchc,stat=allocerr)

    if ( allocerr .ne. 0 ) then
        write(*,*) 'Deallocation error - Main.'
        stop
    end if
    
    stop

end program ils_tspn
