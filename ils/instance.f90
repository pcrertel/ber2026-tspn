! =====================================================================
!  module instance -> tipos derivados, parametros globais, inputdata,
!                     solution and benchmark I/O, dswapr, dswapi, evalf,
!                     drand
!
!  Depende de: geometry (polygon_centroid_2d, chamado por inputdata)
! =====================================================================
module instance

    use geometry

    implicit none

    type :: instance_type
        integer :: npol,nvmin,nvmax,nvert,npol1,npol2,vsize,lwsize,lenfilename,ncand
        real(kind=8) :: xymax,gtspopt,gtspbcdopt
        character(len=150) :: filename,incumbfile
        logical :: hasref = .false.       ! whether a reference GTSP+BCD tour was loaded
        integer, allocatable :: nvp(:)
        integer, allocatable :: cand(:,:)
        integer, allocatable :: reftour(:) ! best-known GTSP+BCD tour (canonicalized), for comparison
        real(kind=8), allocatable :: vcoor(:,:,:),barycenters(:,:),bbox(:,:),canddist(:,:)
    end type instance_type

    type :: parameter_type
        integer :: jmin,jmax,ell_np_max,strlen,reverse,cardZ,&
        numdbmoves,bsk,vnd_type,seedrun,ncand_max,bestfirst   ! bestfirst: 0 = first improvement, 1 = best improvement
        ! ncand_max: K of the candidate lists (neighbor lists). See the
        ! validation block of inputdata for what it controls.
        real(kind=8) :: seed,eps,h
        character(len=256) :: bks_filename
    end type parameter_type

    type :: counter_type
        integer :: bcdmcalls,bcdmcic,stopbcdf,stopbcdcic,vndcal,nscal,hcalls,ilsiter,&
        twoptcall,treeoptcall,swapcall,insercall,dbcall,relocall,bscall,gutincall,&
        maxbcdcic,bestilsiter,netared,netareheat,nrestnn
        real(kind=8) :: gapils,costils,bestime,start,finish
        character(len=80) :: seedfile
    end type counter_type

    ! PARAMETERS
    logical :: debug = .false.       ! Enables the consistency checks of the incremental (delta) costs
    logical :: logprogress = .false. ! Enables the per-iteration (-2) progress lines in the incumbent file

    ! CALIBRATION MODE (irace). Set from the environment variable ILS_TUNING
    ! (any value other than '0'), exported by the target-runner.
    !
    ! In this mode the program produces EXACTLY ONE output file: the incumbent
    ! file, whose literal name is the first stdin record, holding a single
    ! number - the cost of the best solution found so far. No benchmark tables,
    ! no solution files, no reference tour, no best-known-cost file. That is all
    ! irace needs, and one file per experiment is what lets the parallel runs
    ! coexist without clobbering each other.
    !
    ! Outside this mode nothing changes: the sweep keeps writing its benchmark
    ! rows, its solution files and its multi-column incumbent progress lines.
    logical :: tuning = .false.

    ! CANDIDATE LISTS. K is param%ncand_max, read from standard input. Each
    ! polygon keeps its K nearest polygons, ordered by inst%canddist; every
    ! pruned neighborhood walks that list and stops as soon as the lower bound
    ! exceeds the edge it is trying to beat (gain criterion / fixed-radius near
    ! neighbor search). Setting ncand_max >= npol-1 recovers the exhaustive
    ! scan exactly.

    ! ACCEPTANCE THRESHOLD (eta, read into param%eps). The update of eta
    ! depends only on the progress of the search: eta is multiplied by h after
    ! every nstag CONSECUTIVE ILS iterations that fail to improve the
    ! incumbent, and is reheated to its initial value as soon as it falls
    ! below etamin. The time limit is a stopping criterion and nothing else, so
    ! a configuration calibrated under one limit governs the same behaviour
    ! under another.
    !
    ! etamin is FIXED, not calibrated: below it the acceptance test
    ! F <= (1+eta) F(best) already takes essentially nothing but improvements,
    ! so there is no reason to let eta fall further. With h = 1 eta stays at
    ! its initial value for the whole run and nstag has no effect, which makes
    ! h = 1 a clean control case for the calibration.
    integer :: nstag = 50                        ! iters without improv. per reduction of eta
    real(kind=8), parameter :: etamin = 1.0d-4   ! floor of eta

    contains

    ! *****************************************************************
    ! *****************************************************************
    ! File name of a path, without the directory part.
    !
    ! The separator is located rather than assumed: the instance path arrives
    ! from standard input and may be relative or absolute, of any length.
    pure function basename(path) result(b)

        implicit none

        ! SCALAR ARGUMENTS
        character(len=*), intent(in) :: path

        ! RESULT
        character(len=len(path)) :: b

        ! LOCAL SCALARS
        integer :: p

        ! achar(92) is the backslash, spelled this way so the meaning does not
        ! depend on whether the compiler treats '\' as an escape.
        p = max( index(path,'/',back=.true.), index(path,achar(92),back=.true.) )

        b = adjustl(path(p+1:))

    end function basename

    ! *****************************************************************
    ! *****************************************************************
    ! Writes the incumbent file of the calibration mode: ONE line holding the
    ! cost of the best solution found so far, in the NORMALIZED scale (the
    ! coordinates divided by inst%xymax). This is the single number irace reads
    ! back.
    !
    ! Normalized and not original scale. It makes no difference to the decisions
    ! irace takes: the elimination test of the race is the Friedman test, which
    ! ranks configurations WITHIN each instance, and inst%xymax is a per-instance
    ! constant, so the ranking is identical either way. It matters if the
    ! scenario ever switches testType to a t-test, or turns on capping/boundMax:
    ! those compare raw costs, and instances whose coordinates differ by orders
    ! of magnitude would then dominate the aggregate. Writing the normalized
    ! value keeps the setup safe under that change.
    !
    ! The file is reopened and rewritten at every improvement. A sequential
    ! write truncates whatever followed, so the file always holds exactly one
    ! record - no risk of a shorter number leaving digits of the previous one
    ! behind. Closing it every time also guarantees the value is on disk when
    ! `timeout` kills the process, which is the normal way a run ends.
    subroutine write_incumbent(inst,cost)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst

        ! SCALAR ARGUMENTS
        real(kind=8), intent(in) :: cost

        ! LOCAL SCALARS
        integer :: u

        open(newunit=u,file=trim(adjustl(inst%incumbfile)),action='write')
        write(u,*) cost
        close(u)

    end subroutine write_incumbent

    ! *****************************************************************
    ! *****************************************************************
    subroutine inputdata(inst,count,param,normalize)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(inout) :: inst
        type(parameter_type), intent(inout) :: param
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        
        ! This routine obtains the input data.
        logical, intent(in) :: normalize

        ! LOCAL SCALARS
        integer :: i,j,k,ell,m,allocerr
        real(kind=8) :: dum,d,dmin,worst
        integer :: iworst
        character(len=80) :: dumcar

        ! LOCAL ARRAYS (used to build the candidate lists)
        real(kind=8), allocatable :: rowd(:)

        ! Read input data

        ! The calibration mode has to be known BEFORE the first read, because
        ! the two modes have different stdin contracts (see below).
        tuning = .false.
        call get_environment_variable('ILS_TUNING', dumcar)
        if ( len_trim(dumcar) .gt. 0 ) tuning = ( trim(adjustl(dumcar)) .ne. '0' )

        read(*,*) inst%incumbfile

        read(*,*) inst%filename

        if ( tuning ) then

            ! ------------------------------------------------------------
            ! CALIBRATION CONTRACT (irace target-runner), 4 records:
            !   1: literal name of the incumbent file (unique per experiment)
            !   2: "<instance path>"   (absolute, as irace passes it)
            !   3: <seed>
            !   4: <nstag> <eps> <h> <strlen> <reverse> <cardZ>
            !      <numdbmoves> <bsk> <vnd_type> <bestfirst> <ncand_max>
            !
            ! nstag is the number of consecutive iterations without improvement
            ! between two reductions of eta. It is a count of iterations and
            ! not of seconds, so a configuration calibrated under one time
            ! limit governs the same behaviour under another.
            !
            ! bestfirst selects the improvement strategy of the neighborhoods
            ! that admit both (2-opt, 3-opt, swap, insertion):
            !     0 = first improvement    1 = best improvement
            !
            ! ncand_max is K, the size of the candidate lists: the one knob
            ! that scales the cost of the 2-opt, the 3-opt, the swap, the
            ! insertion and the string relocation all at once.
            !
            ! seedrun is NOT read: it exists to decorrelate the 5 repetitions
            ! of the sweep, and irace already hands out a distinct seed per
            ! experiment.
            ! ------------------------------------------------------------
            read(*,*) param%seed

            read(*,*) nstag,param%eps,param%h,param%strlen,param%reverse,&
            param%cardZ,param%numdbmoves,param%bsk,param%vnd_type,param%bestfirst,&
            param%ncand_max

            param%seedrun      = 0
            param%bks_filename = ''

            ! No reference costs are read in this mode, so no gap is computed.
            inst%gtspopt    = 0.0d0
            inst%gtspbcdopt = 0.0d0

        else

            ! ------------------------------------------------------------
            ! SWEEP CONTRACT (run_sweep_task.sh), 5 records
            !
            ! The parameter list carries the SAME eleven values, in the SAME
            ! order, as the calibration contract, so a configuration returned
            ! by irace goes into the final experiments unchanged:
            !   <nstag> <eps> <h> <strlen> <reverse> <cardZ>
            !   <numdbmoves> <bsk> <vnd_type> <bestfirst> <ncand_max>
            !
            ! The first field is nstag, as in calibration mode. The time limit
            ! of a run is not read by this program at all: it bounds the run
            ! from outside, through the shell `timeout`.
            !
            ! ncand_max ends the list so that the sweep sets K explicitly
            ! instead of inheriting a hard-coded 15. This is a LIST-DIRECTED
            ! read: it keeps consuming records until the whole list is filled,
            ! so run_sweep_task.sh may go on splitting it over two echo lines,
            ! as long as ncand_max is the last field of the second one.
            ! ------------------------------------------------------------
            read(*,*) param%bks_filename

            read(*,*) param%seed,param%seedrun

            read(*,*) nstag,param%eps,param%h,param%strlen,param%reverse,&
            param%cardZ,param%numdbmoves,param%bsk,param%vnd_type,param%bestfirst,&
            param%ncand_max


        end if

        ! =================================================================
        ! Validation of the tunable parameters
        !
        ! Every parameter below arrives from standard input and is swept
        ! during calibration, so a bad value must fail HERE, loudly, before
        ! any computation - not deep inside a neighborhood. Two of them fail
        ! in ways that are easy to miss otherwise:
        !   bsk      : outside {2,3} BalaSimonetti leaves its workspace
        !              uninitialized and calls ShortestPath with nnodes = -1,
        !              which segfaults.
        !   vnd_type : outside {0,1} VND silently performs NO neighborhood
        !              search at all. The run then completes with exit code 0
        !              and reports the initial GTSP+BCD cost as if it were the
        !              ILS result - indistinguishable, in a calibration table,
        !              from a legitimate configuration.
        !
        ! The messages go to stderr (unit 0) rather than stdout: in
        ! calibration mode the target-runner discards stdout and captures
        ! stderr, so this is where a rejected configuration becomes readable.
        ! =================================================================
        if ( param%bsk .ne. 2 .and. param%bsk .ne. 3 ) then
            write(0,*) 'bsk = ',param%bsk,' - only 2 and 3 are implemented ', &
            'in BalaSimonetti - inputdata.'
            stop 1
        end if

        ! 0 = fixed neighborhood order, 1 = order drawn at random per VND call.
        if ( param%vnd_type .ne. 0 .and. param%vnd_type .ne. 1 ) then
            write(0,*) 'vnd_type = ',param%vnd_type,' - use 0 for the fixed ', &
            'neighborhood order or 1 for the random one - inputdata.'
            stop 1
        end if

        if ( param%bestfirst .ne. 0 .and. param%bestfirst .ne. 1 ) then
            write(0,*) 'bestfirst = ',param%bestfirst,' - it is a flag: 0 for ', &
            'first improvement, 1 for best improvement - inputdata.'
            stop 1
        end if

        if ( param%reverse .ne. 0 .and. param%reverse .ne. 1 ) then
            write(0,*) 'reverse = ',param%reverse,' - it is a flag, use 0 or 1; ', &
            'StringRelocN tests it against 1, so any other value silently ', &
            'means 0 - inputdata.'
            stop 1
        end if

        if ( param%cardZ .lt. 0 .or. param%numdbmoves .lt. 0 ) then
            write(0,*) 'cardZ and numdbmoves must both be non-negative', &
            ' - inputdata.'
            stop 1
        end if

        ! strlen is the MAXIMUM length of the string moved by StringRelocN,
        ! which tries every length from 2 up to strlen in the same call
        ! (length 1 is the insertion, neighborhood 6). With strlen < 2 its
        ! loop over lengths is empty and the neighborhood silently searches
        ! nothing, so the VND would run with seven neighborhoods, not eight.
        if ( param%strlen .lt. 2 ) then
            write(0,*) 'strlen = ',param%strlen,' - it is the maximum string ', &
            'length of the string relocation, which starts at 2; a value ', &
            'below 2 disables that neighborhood - inputdata.'
            stop 1
        end if

        ! ncand_max is K, the size of the candidate (nearest-neighbor) lists.
        ! It sets how far every neighborhood scan looks before the pruning
        ! test cuts it off, so it scales the cost of the 2-opt, swap,
        ! insertion, 3-opt and string-relocation searches all at once - and
        ! also the O(K * npol^2) construction of the lists themselves in this
        ! routine. It is capped at npol-1 below, so a value larger than the
        ! instance simply means "every other polygon is a candidate".
        if ( param%ncand_max .lt. 1 ) then
            write(0,*) 'ncand_max = ',param%ncand_max,' must be at least 1 ', &
            '(it is K, the size of the candidate lists) - inputdata.'
            stop 1
        end if

        ! Read in both modes, as the first field of the parameter list.
        if ( nstag .lt. 1 ) then
            write(0,*) 'nstag = ',nstag,' must be at least 1 (it is the ', &
            'number of consecutive iterations without improvement between ', &
            'two reductions of eta) - inputdata.'
            stop 1
        end if

        if ( param%eps .lt. 0.0d0 ) then
            write(0,*) 'eps = ',param%eps,' must be non-negative - inputdata.'
            stop 1
        end if

        ! h is the geometric factor that shrinks eps in the ILS acceptance
        ! criterion; outside (0,1] it would never tighten the acceptance.
        if ( param%h .le. 0.0d0 .or. param%h .gt. 1.0d0 ) then
            write(0,*) 'h = ',param%h,' must lie in (0,1] - inputdata.'
            stop 1
        end if


        param%ell_np_max = 3000
        inst%lenfilename = len_trim(inst%filename)
        write(count%seedfile,80) param%seedrun

        count%maxbcdcic = 200

        ! Each seedrun gets a random stream of its own, and not merely a
        ! different starting position in a shared one. On the large instances
        ! the ILS completes few iterations and most of the time goes to the
        ! first, deterministic descent, so streams that differ only by a few
        ! positions would make the repetitions of one instance nearly
        ! identical and the replication would be no replication at all.
        param%seed = param%seed + 1000.0d0 * dble(param%seedrun)
        do k = 1, param%seedrun
            dum = drand(param%seed)
        end do
        ! write(99,*) 'Semente: ',param%seed

        ! ILS parameters values used in the paper
        param%jmin = 1          ! VND param
        param%jmax = 8          ! VND param

        ! Read instance file
        ! write(99,*) 'Instance file name = ',trim(adjustl(inst%filename))
        open(unit=10,file=trim(adjustl(inst%filename)))
        
        read(10,*) inst%npol,inst%nvmax

        inst%ncand = min( param%ncand_max, inst%npol-1 )
        allocate(inst%nvp(inst%npol),inst%vcoor(2,inst%nvmax,inst%npol),&
        inst%barycenters(2,inst%npol),inst%bbox(4,inst%npol),&
        inst%cand(inst%ncand,inst%npol),inst%canddist(inst%ncand,inst%npol),stat=allocerr)

        if ( allocerr .ne. 0 ) then
            write(*,*) 'Allocation error - inputdata.'
            stop
        end if

        inst%npol1 = 0
        inst%npol2 = 0
        inst%nvmin = inst%nvmax
        do i = 1,inst%npol            
            read(10,*) inst%nvp(i)
            if ( inst%nvp(i) .lt. inst%nvmin ) then
                inst%nvmin = inst%nvp(i)
            end if
            if ( inst%nvp(i) .eq. 1  ) then
                inst%npol1 = inst%npol1+1
            end if
            if ( inst%nvp(i) .eq. 2  ) then
                inst%npol2 = inst%npol2+1
            end if
            do j = 1,inst%nvp(i)
                read(10,*) inst%vcoor(1:2,j,i)
            end do
        end do

        close(10)

        inst%nvert = sum(inst%nvp(1:inst%npol))
        inst%vsize = (inst%npol+1)*max(inst%nvmax,8)
        inst%lwsize = inst%vsize*max(inst%nvmax,3)

        if ( normalize ) then
            inst%xymax = - huge( 1.0d0 )
            do k = 1,inst%npol
                do j = 1,inst%nvp(k)
                    inst%xymax = max( inst%xymax, abs( inst%vcoor(1,j,k) ), abs( inst%vcoor(2,j,k) ) )
                end do
            end do
            ! write(*,*) 'xymax = ',inst%xymax
            do k = 1,inst%npol
                do j = 1,inst%nvp(k)
                    inst%vcoor(1:2,j,k) = inst%vcoor(1:2,j,k) / inst%xymax
                    ! write(*,*) inst%vcoor(1:2,j,k)
                end do
            end do
        else
            inst%xymax = 1.0d0
        end if

        ! Computes the bounding box of each polygon (xmin,xmax,ymin,ymax), 
        ! used by minpol for the early rejection of the point-in-polygon 
        ! and segment intersection tests
        do k = 1, inst%npol
            inst%bbox(1,k) = minval( inst%vcoor(1,1:inst%nvp(k),k) )
            inst%bbox(2,k) = maxval( inst%vcoor(1,1:inst%nvp(k),k) )
            inst%bbox(3,k) = minval( inst%vcoor(2,1:inst%nvp(k),k) )
            inst%bbox(4,k) = maxval( inst%vcoor(2,1:inst%nvp(k),k) )
        end do

        ! =================================================================
        ! Candidate lists (neighbor lists) - Section 3.1 of Schmidt & Irnich
        ! For each polygon k, cand(1:ncand,k) holds its ncand nearest 
        ! polygons, ORDERED by increasing canddist, where
        !     canddist(m,k) = min distance between a vertex of k and a 
        !                     vertex of cand(m,k)
        ! is a LOWER BOUND on the length of any tour edge between the two
        ! polygons. G2opt uses it with the gain criterion: a 2-opt move
        ! can only improve if one of the new edges is shorter than the tour
        ! edge it replaces, so scanning the list in increasing order and
        ! stopping at the first canddist >= (removed edge length) discards,
        ! with no risk, every move that provably cannot improve.
        ! Computed ONCE: O(npol^2 * nvmax^2).
        ! =================================================================
        allocate(rowd(inst%npol),stat=allocerr)
        if ( allocerr .ne. 0 ) then
            write(*,*) 'Allocation error in inputdata (candidate lists)'
            stop
        end if

        do k = 1, inst%npol
            ! Distance from polygon k to every other polygon
            do j = 1, inst%npol
                if ( j .eq. k ) then
                    rowd(j) = huge( 1.0d0 )
                    cycle
                end if
                ! LOWER BOUND on the length of any tour edge between the
                ! polygons k and j. The visiting points are CONTINUOUS points
                ! inside the polygons, NOT vertices, so the minimum over pairs
                ! of VERTICES is not a valid bound: for two squares [0,1]^2 and
                ! [0.5,1.5]x[2,3] it gives 1.118 while the points (0.5,1) and
                ! (0.5,2), both feasible, are 1.0 apart. Using it would let the
                ! candidate scans stop too early and lose improving moves.
                ! If the bounding boxes are disjoint, the polygons are disjoint
                ! and the exact distance between them is the minimum over
                ! vertex-to-edge pairs (in both directions), which is tight.
                ! Otherwise fall back to the distance between the bounding
                ! boxes, which is always valid (both points lie inside them).
                if ( inst%bbox(2,k) .lt. inst%bbox(1,j) .or. inst%bbox(2,j) .lt. inst%bbox(1,k) .or. &
                     inst%bbox(4,k) .lt. inst%bbox(3,j) .or. inst%bbox(4,j) .lt. inst%bbox(3,k) ) then
                    dmin = huge( 1.0d0 )
                    do i = 1, inst%nvp(k)
                        do ell = 1, inst%nvp(j)
                            d = pt_seg( inst%vcoor(1:2,i,k), inst%vcoor(1:2,ell,j), &
                            inst%vcoor(1:2,mod(ell,inst%nvp(j))+1,j) )
                            if ( d .lt. dmin ) dmin = d
                        end do
                    end do
                    do ell = 1, inst%nvp(j)
                        do i = 1, inst%nvp(k)
                            d = pt_seg( inst%vcoor(1:2,ell,j), inst%vcoor(1:2,i,k), &
                            inst%vcoor(1:2,mod(i,inst%nvp(k))+1,k) )
                            if ( d .lt. dmin ) dmin = d
                        end do
                    end do
                else
                    dmin = sqrt( max( 0.0d0, max( inst%bbox(1,j)-inst%bbox(2,k), &
                    inst%bbox(1,k)-inst%bbox(2,j) ) )**2 &
                    + max( 0.0d0, max( inst%bbox(3,j)-inst%bbox(4,k), &
                    inst%bbox(3,k)-inst%bbox(4,j) ) )**2 )
                end if
                rowd(j) = dmin
            end do

            ! Selects the ncand smallest by repeated extraction of the minimum
            ! (ncand is small, so this is cheaper than a full sort)
            do m = 1, inst%ncand
                iworst = 1
                worst = rowd(1)
                do j = 2, inst%npol
                    if ( rowd(j) .lt. worst ) then
                        worst = rowd(j)
                        iworst = j
                    end if
                end do
                inst%cand(m,k) = iworst
                inst%canddist(m,k) = worst
                rowd(iworst) = huge( 1.0d0 )
            end do
        end do

        deallocate(rowd)

        ! Calculate the barycenters
        do k = 1, inst%npol         ! Loops over the polygons
            if ( inst%nvp(k) .eq. 1 ) then
                inst%barycenters(1:2,k) = inst%vcoor(1:2,1,k)
            else if ( inst%nvp(k) .eq. 2 ) then
                inst%barycenters(1:2,k) = (inst%vcoor(1:2,1,k) + inst%vcoor(1:2,2,k)) / 2.0d0
            else ! inst%nvp(k) .ge. 3
                call polygon_centroid_2d ( inst%nvp(k), inst%vcoor(1:2,1:inst%nvp(k),k), &
                inst%barycenters(1:2,k) )    
            end if
        end do

        ! open(unit=14,file='tables/out-ils-tspn-seed'&
        ! //trim(adjustl(count%seedfile))//'.txt')
        ! read(14,*) dumcar,inst%gtspopt
        ! close(14)

        ! The file of reference costs carries, per instance:
        !   <name>  <GTSP cost>  <GTSP + BCD cost>
        ! gtspopt    = length of the best known GTSP tour, whose visit points
        !              are vertices of the clusters
        ! gtspbcdopt = that same tour after the visit points are recomputed
        !              with the BCD, already in the continuous space of the
        !              TSPN
        !
        ! Skipped in calibration mode: these values only feed the gap columns
        ! of the benchmark table, which is not written then. Skipping them also
        ! removes the requirement that every tuning instance have a line in
        ! optsol_tspn.dat.
        if ( .not. tuning ) then
            open(unit=14,file=trim(adjustl(param%bks_filename)),status='old')
            read(14,*) dumcar,inst%gtspopt,inst%gtspbcdopt
            close(14)
        end if

        ! Initializes counters
        count%bcdmcalls = 0               ! BCD calls
        count%bcdmcic = 0                 ! BCD cycles
        count%stopbcdf = 0                ! BCD stopping criterion counter: low decrease in objective function
        count%stopbcdcic = 0              ! BCD stopping criterion counter: maxbcdcic was achieved
        count%vndcal = 0                  ! VND calls
        count%nscal = 0                   ! NeighborhoodSearch calls
        count%hcalls = 0
        count%ilsiter = 0
        count%twoptcall = 0
        count%treeoptcall = 0
        count%swapcall = 0
        count%insercall = 0
        count%dbcall = 0
        count%relocall = 0
        count%bscall = 0
        count%gutincall = 0
        count%netared    = 0
        count%netareheat = 0
        count%nrestnn    = 0
        count%bestilsiter = 0

        ! NON-EXECUTABLE STATEMENTS
        80 format(I3)
    end subroutine inputdata

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    ! Appends one summary row per run (cost, gap, times, counters) to the
    ! table tables/benchmark_summary.csv. The code version is read from the
    ! environment variable ILS_VERSION (default: 'baseline'). To inspect:
    !   column -s';' -t tables/benchmark_summary.csv | less -S

    subroutine write_benchmark_row(inst,param,count,finalcost,status,tour)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(parameter_type), intent(in) :: param
        type(counter_type), intent(inout) :: count

        ! SCALAR ARGUMENTS
        real(kind=8), intent(in) :: finalcost   ! cost (normalized) of the best solution so far
        character(len=*), intent(in) :: status  ! 'partial' (during the search) or 'final'

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(inst%npol)  ! incumbent tour (compared vs reference)

        ! Rewrites the ONE-ROW benchmark file of THIS run:
        !     tables/bench-<instance>-seed<seedrun>-<version>.csv
        ! It is called at every incumbent improvement (status = 'partial') and
        ! at the natural end of the program (status = 'final'). Therefore the
        ! row survives even when the run is killed by the shell timeout: it
        ! simply keeps the state of the last improvement. The code version is
        ! read from the environment variable ILS_VERSION (default 'baseline').
        ! After all runs, run_master_debug.sh consolidates every bench-*.csv
        ! into tables/benchmark_summary.csv. To inspect:
        !     column -s';' -t tables/benchmark_summary.csv | less -S

        ! LOCAL SCALARS
        integer :: unit, dt(8)
        real(kind=8) :: totaltime, avgcic, gap, gapbcd
        character(len=32) :: version
        character(len=16) :: stamp_d, stamp_h, seedstr
        character(len=300) :: rowfile
        character(len=8) :: tourmatch
        character(len=32) :: gapbcdstr

        ! PARAMETERS
        real(kind=8), parameter :: zerotol = 1.0d-6   ! 'zero-length' threshold, normalized scale

        ! Tour vs best-known GTSP+BCD tour ('same'/'diff'/'na').
        ! Canonicalizes a copy in memory; O(npol), no disk I/O here.
        tourmatch = tourmatch_str(inst,tour)

        ! Elapsed time up to this point
        call cpu_time(count%finish)
        totaltime = count%finish - count%start

        ! Average number of inner cycles per BCD call
        avgcic = 0.0d0
        if ( count%bcdmcalls .gt. 0 ) then
            avgcic = dble(count%bcdmcic) / dble(count%bcdmcalls)
        end if

        ! Gap with respect to the best known GTSP tour, whose visit points are
        ! vertices of the clusters, on the denormalized cost
        gap = 100.0d0 * ( finalcost * inst%xymax - inst%gtspopt ) / inst%gtspopt
        ! gap_bcd_pct. For the instances whose optimal TSPN tour has length zero
        ! (all neighborhoods share a point), the reference GTSP+BCD cost is a
        ! floating-point residual (~1e-15 in the normalized scale) and the
        ! relative gap is undefined: 100*(c - c*)/c* turns two residuals into an
        ! arbitrary percentage. The reference is taken as zero when, in the
        ! normalized scale, it does not exceed zerotol = 1e-6 (the smallest
        ! genuine reference among the 235 instances is 0.405). The gap is then
        ! written as 0 if the ILS tour also has length zero, and as 'na'
        ! otherwise, in which case the absolute cost must be reported.
        if ( inst%gtspbcdopt / inst%xymax .gt. zerotol ) then
            gapbcd = 100.0d0 * ( finalcost * inst%xymax - inst%gtspbcdopt ) / inst%gtspbcdopt
            write(gapbcdstr,'(f0.4)') gapbcd
        else if ( finalcost .le. zerotol ) then
            write(gapbcdstr,'(f0.4)') 0.0d0
        else
            gapbcdstr = 'na'
        end if

        ! Label of the code version (environment variable ILS_VERSION)
        call get_environment_variable('ILS_VERSION', version)
        if ( len_trim(version) .eq. 0 ) version = 'baseline'

        ! Date/time
        call date_and_time(values=dt)
        write(stamp_d,'(i4.4,a,i2.2,a,i2.2)') dt(1),'-',dt(2),'-',dt(3)
        write(stamp_h,'(i2.2,a,i2.2,a,i2.2)') dt(5),':',dt(6),':',dt(7)
        write(seedstr,'(i0)') param%seedrun

        ! One file per run, rewritten at every call
        rowfile = 'tables/bench-'//trim(basename(inst%filename))//&
        '-seed'//trim(seedstr)//'-'//trim(adjustl(version))//'.csv'

        open(newunit=unit, file=rowfile, action='write', status='replace')

        ! The columns come in two groups: those of the last improvement of the
        ! incumbent and those of the moment the row is written.
        write(unit,'(a)') 'date;time;version;status;instance;npol;nvert;seedrun;'// &
        'cost_norm;cost_orig;bks;gap_pct;bks_bcd;gap_bcd_pct;time_last_improv;iter_last_improv;'// &
        'current_time;current_iter;vnd_calls;ns_calls;'// &
        'bcd_calls;bcd_cycles;avg_cyc_per_bcd;stop_f;stop_cic;'// &
        'twoopt;threeopt;swap;insert;dbridge;reloc;balas;gutin;'// &
        'eta_reduct;eta_reheat;nn_restart;tour_match'

        write(unit,100) trim(stamp_d), trim(stamp_h), trim(version), trim(status), &
            trim(adjustl(inst%filename)), inst%npol, inst%nvert, param%seedrun, &
            finalcost, finalcost*inst%xymax, inst%gtspopt, gap, &
            inst%gtspbcdopt, trim(gapbcdstr), &
            count%bestime, count%bestilsiter, & ! of the last improvement
            totaltime, count%ilsiter, &         ! of the current moment
            count%vndcal, count%nscal, &
            count%bcdmcalls, count%bcdmcic, avgcic, count%stopbcdf, count%stopbcdcic, &
            count%twoptcall, count%treeoptcall, count%swapcall, count%insercall, &
            count%dbcall, count%relocall, count%bscall, count%gutincall, &
            count%netared, count%netareheat, count%nrestnn, trim(tourmatch)

        close(unit)

        ! NON-EXECUTABLE STATEMENTS
        ! Matches the order of the columns written above.
100     format(a,';',a,';',a,';',a,';',a,';',i0,';',i0,';',i0,';', &
               f0.8,';',f0.4,';',f0.4,';',f0.4,';', &
               f0.4,';',a,';', &        ! bks_bcd ; gap_bcd_pct (text: number or 'na')
               f0.2,';',i0,';', &       ! time_last_improv ; iter_last_improv
               f0.2,';',i0,';', &       ! current_time ; current_iter
               i0,';',i0,';', &         ! vnd_calls ; ns_calls
               i0,';',i0,';',f0.2,';',i0,';',i0,';', &
               i0,';',i0,';',i0,';',i0,';',i0,';',i0,';',i0,';',i0,';',i0,';',i0,';',i0,';',a)

    end subroutine write_benchmark_row

    ! ------------------------------------------------------------------
    ! Canonicalizes a cyclic tour: rotates it so that polygon 1 sits at
    ! position 1 and the neighbour of 1 with the SMALLEST index sits at
    ! position 2. This yields a UNIQUE, direction-independent representative
    ! of the cycle, so two tours describe the same cycle iff their canonical
    ! forms are identical. The same reordering is applied to the visiting
    ! points x(1:2,:). O(npol); meant to be called ONCE, after the search.
    ! ------------------------------------------------------------------
    subroutine canonicalize_tour(npol,tour,x)

        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: npol

        ! ARRAY ARGUMENTS
        integer, intent(inout) :: tour(npol)
        real(kind=8), intent(inout) :: x(2,npol)

        ! LOCAL SCALARS
        integer :: i,k,pos,iprev,inext,step,src

        ! LOCAL ARRAYS
        integer :: tour_tmp(npol)
        real(kind=8) :: x_tmp(2,npol)

        ! Locate the position of polygon 1 in the tour
        pos = 1
        do i = 1,npol
            if ( tour(i) .eq. 1 ) then
                pos = i
                exit
            end if
        end do

        ! Cyclic neighbours of position pos
        iprev = mod(pos-2+npol,npol) + 1   ! position pos-1 (cyclic)
        inext = mod(pos,npol) + 1          ! position pos+1 (cyclic)

        ! Travel towards the smaller-index neighbour (ties: keep +1)
        if ( tour(inext) .le. tour(iprev) ) then
            step = 1
        else
            step = -1
        end if

        ! Reorder into temporaries starting at pos, stepping by 'step'
        do k = 1,npol
            src = mod(pos-1+step*(k-1)+npol, npol) + 1
            tour_tmp(k)    = tour(src)
            x_tmp(1:2,k)   = x(1:2,src)
        end do

        ! Write back
        tour(1:npol)    = tour_tmp(1:npol)
        x(1:2,1:npol)   = x_tmp(1:2,1:npol)

    end subroutine canonicalize_tour

    ! ------------------------------------------------------------------
    ! Same canonicalization as above, but for a tour vector alone (no
    ! visiting points). Used on the reference tour, which we read as
    ! integers only. Idempotent when the input is already canonical.
    ! ------------------------------------------------------------------
    subroutine canonicalize_tour_int(npol,tour)

        implicit none

        integer, intent(in) :: npol
        integer, intent(inout) :: tour(npol)

        integer :: i,k,pos,iprev,inext,step,src
        integer :: tour_tmp(npol)

        pos = 1
        do i = 1,npol
            if ( tour(i) .eq. 1 ) then
                pos = i
                exit
            end if
        end do

        iprev = mod(pos-2+npol,npol) + 1
        inext = mod(pos,npol) + 1

        if ( tour(inext) .le. tour(iprev) ) then
            step = 1
        else
            step = -1
        end if

        do k = 1,npol
            src = mod(pos-1+step*(k-1)+npol, npol) + 1
            tour_tmp(k) = tour(src)
        end do

        tour(1:npol) = tour_tmp(1:npol)

    end subroutine canonicalize_tour_int

    ! ------------------------------------------------------------------
    ! Writes the current incumbent solution in the SAME format as the
    ! reference files gtsp-toursol/gtsp-bdc-sol-<inst>.dat:
    !   npol lines of  <polygon_index>  <x>  <y>   (ORIGINAL scale)
    !   1 final line with the total cost (ORIGINAL scale)
    ! The file name carries seed and version to avoid collisions between
    ! the parallel runs (GNU parallel).
    !
    ! Called at EVERY incumbent improvement (and once at the end), exactly
    ! like write_benchmark_row, so the file survives a run killed by the
    ! shell timeout: it always holds the best solution found so far.
    !
    ! Self-contained: it canonicalizes a COPY of the tour/points (starting
    ! at polygon 1), so the working arrays of the search are NEVER modified.
    ! O(npol); the tiny disk write mirrors what write_benchmark_row already
    ! does at the same points.
    ! ------------------------------------------------------------------
    subroutine write_solution_file(inst,param,tour,x,cost,prefix)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        type(parameter_type), intent(in) :: param

        ! SCALAR ARGUMENTS
        real(kind=8), intent(in) :: cost

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(inst%npol)
        real(kind=8), intent(in) :: x(2,inst%npol)

        ! OPTIONAL ARGUMENT: file name prefix, 'ils-sol-' by default
        ! ('ils-init-' for the initial solution)
        character(len=*), intent(in), optional :: prefix

        ! LOCAL SCALARS
        integer :: u,k
        character(len=32)  :: version,seedstr
        character(len=400) :: solfile
        character(len=150) :: bname

        ! LOCAL ARRAYS (working copies, so the search arrays are untouched)
        integer :: tcopy(inst%npol)
        real(kind=8) :: xcopy(2,inst%npol)

        ! Canonicalize a copy: uniform reporting starting at polygon 1
        tcopy(1:inst%npol)  = tour(1:inst%npol)
        xcopy(1:2,1:inst%npol) = x(1:2,1:inst%npol)
        call canonicalize_tour(inst%npol,tcopy,xcopy)

        call get_environment_variable('ILS_VERSION', version)
        if ( len_trim(version) .eq. 0 ) version = 'baseline'
        write(seedstr,'(i0)') param%seedrun

        ! Instance name without the directory and without the '.dat' extension
        bname = basename(inst%filename)

        if ( present(prefix) ) then
            solfile = 'ils-toursol/'//prefix
        else
            solfile = 'ils-toursol/ils-sol-'
        end if
        solfile = trim(solfile)//bname(1:len_trim(bname)-4)// &
        '-seed'//trim(seedstr)//'-'//trim(adjustl(version))//'.dat'

        open(newunit=u,file=solfile,action='write',status='replace')
        do k = 1,inst%npol
            write(u,*) tcopy(k), xcopy(1,k)*inst%xymax, xcopy(2,k)*inst%xymax
        end do
        write(u,*) cost*inst%xymax
        close(u)

    end subroutine write_solution_file

    ! ------------------------------------------------------------------
    ! Reads the reference (best-known GTSP+BCD) tour ONCE from
    ! gtsp-toursol/gtsp-bdc-sol-<inst>.dat, canonicalizes it and stores it
    ! in inst%reftour (with inst%hasref = .true.). Only the leading integer
    ! (the polygon index) of each line is used. If the file is missing or
    ! unreadable, inst%hasref stays .false. and comparisons report 'na'.
    ! Call this ONCE, before the search. No disk I/O happens afterwards.
    ! ------------------------------------------------------------------
    subroutine load_reference_tour(inst)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(inout) :: inst

        ! LOCAL SCALARS
        integer :: u,k,ios,allocerr

        character(len=400) :: reffile

        ! LOCAL ARRAYS
        logical :: seen(inst%npol)

        inst%hasref = .false.

        if ( allocated(inst%reftour) ) deallocate(inst%reftour)
        allocate(inst%reftour(inst%npol),stat=allocerr)
        if ( allocerr .ne. 0 ) return

        reffile = 'gtsp-toursol/gtsp-bdc-sol-'//trim(basename(inst%filename))

        open(newunit=u,file=reffile,action='read',status='old',iostat=ios)
        if ( ios .ne. 0 ) return

        ! Each reference line is "<int> <x> <y>"; list-directed read grabs the
        ! leading integer and the record advances to the next line.
        do k = 1,inst%npol
            read(u,*,iostat=ios) inst%reftour(k)
            if ( ios .ne. 0 ) then
                close(u)
                return
            end if
        end do
        close(u)

        ! The reference must be a permutation of 1..npol. A file with a repeated
        ! and a missing index (3 of the 235 files on 15/09/2026) would make every
        ! comparison report 'diff'; it is ignored instead, so tour_match = 'na'.
        seen = .false.
        do k = 1,inst%npol
            if ( inst%reftour(k) .lt. 1 .or. inst%reftour(k) .gt. inst%npol ) return
            if ( seen(inst%reftour(k)) ) return
            seen(inst%reftour(k)) = .true.
        end do

        call canonicalize_tour_int(inst%npol,inst%reftour)
        inst%hasref = .true.

    end subroutine load_reference_tour

    ! ------------------------------------------------------------------
    ! In-memory comparison of a tour with the reference stored in inst.
    ! Canonicalizes a COPY of 'tour' (the working tour is never modified)
    ! and compares it, element by element, with inst%reftour. Only the
    ! tour is compared, never the visiting points. Returns:
    !   'same' - identical cycle    'diff' - different cycle
    !   'na'   - no reference available
    ! O(npol), no disk I/O: safe to call at every incumbent improvement.
    ! ------------------------------------------------------------------
    function tourmatch_str(inst,tour) result(s)

        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst

        ! ARRAY ARGUMENTS
        integer, intent(in) :: tour(inst%npol)

        ! RESULT
        character(len=8) :: s

        ! LOCAL SCALARS
        integer :: k

        ! LOCAL ARRAYS
        integer :: tcopy(inst%npol)

        if ( .not. inst%hasref ) then
            s = 'na'
            return
        end if

        tcopy(1:inst%npol) = tour(1:inst%npol)
        call canonicalize_tour_int(inst%npol,tcopy)

        s = 'same'
        do k = 1,inst%npol
            if ( tcopy(k) .ne. inst%reftour(k) ) then
                s = 'diff'
                exit
            end if
        end do

    end function tourmatch_str

    ! *****************************************************************
    ! *****************************************************************

    subroutine dswapr(a,b)

        implicit none

        ! SCALAR ARGUMENTS
        real(kind=8), intent(inout) :: a,b

        ! On output, the values of a and b have been interchanged.
        ! Swap between REAL numbers.

        ! LOCAL SCALARS
        real(kind=8) :: temp

        temp = a
        a = b
        b = temp
    end subroutine dswapr

    ! *****************************************************************
    ! *****************************************************************

    subroutine dswapi(a,b)

        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(inout) :: a,b

        ! On output, the values of a and b have been interchanged.
        ! Swap between INTEGER numbers.

        ! LOCAL SCALARS
        integer :: temp

        temp = a
        a = b
        b = temp
    end subroutine dswapi

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    subroutine evalf(npol,x,f)

        implicit none

        ! SCALAR ARGUMENTS
        integer, intent(in) :: npol
        real(kind=8), intent(out) :: f
        
        ! ARRAY ARGUMENTS
        real(kind=8), intent(in) :: x(2,npol)

        ! This routine must compute the objective function of the TSPN
        ! problem, i.e., the total distance of a given tour x.

        ! LOCAL SCALARS
        integer :: k
        real(8) :: dx,dy

        f = 0.0d0

        do k = 1, npol-1
            dx = x(1,k) - x(1,k + 1)
            dy = x(2,k) - x(2,k + 1)
            f = f + sqrt( dx * dx + dy * dy )
        end do

        dx = x(1,npol) - x(1,1)
        dy = x(2,npol) - x(2,1)
        f = f + sqrt( dx * dx + dy * dy )
    end subroutine evalf

    ! *****************************************************************
    ! *****************************************************************
    ! ok
    real(kind=8)  function drand(ix)
        implicit none
        ! This is the random number generator of Schrage:
        !
        ! L. Schrage, A more portable Fortran random number generator, ACM
        ! Transactions on Mathematical Software 5 (1979), 132-138.
        ! SCALAR ARGUMENT
        real(kind=8), intent(inout) :: ix

        ! LOCAL ARRAYS
        real(kind=8) :: a,p,b15,b16,xhi,xalo,leftlo,fhi,k

        data a/16807.d0/,b15/32768.d0/,b16/65536.d0/,p/2147483647.d0/

        xhi= ix/b16
        xhi= xhi - dmod(xhi,1.d0)
        xalo= (ix-xhi*b16)*a
        leftlo= xalo/b16
        leftlo= leftlo - dmod(leftlo,1.d0)
        fhi= xhi*a + leftlo
        k= fhi/b15
        k= k - dmod(k,1.d0)
        ix= (((xalo-leftlo*b16)-p)+(fhi-k*b15)*b16)+k
        if (ix.lt.0) ix= ix + p
        drand= ix*4.65661030875d-10

        return

    end function drand

end module instance
