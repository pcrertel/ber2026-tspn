! Stage 3 of the GTSP -> TSPN conversion pipeline.
!
! Reads a GTSP instance whose clusters have been sorted by angle (stage 2)
! and turns every cluster into the polygonal neighbourhood that replaces it,
! writing the TSPN instance out.
!
! Usage:
!     stage3_build_polygons <input.dat> <output-dir> [<plot-dir>]
!
! Both directories must already exist.  MetaPost figures are written only
! when a plot directory is given.
!
! A cluster becomes a polygon as follows.  One point stays a point, and a set
! of collinear points becomes the segment joining the two that are farthest
! apart.  Otherwise the convex hull of the cluster is built, and up to
! kinsert = 3 triangular slices are carved out of it (kinsert is read from
! the environment variable TSPN_KHAT when it is set; TSPN_KHAT=0 stops at the
! convex hull and yields convex neighbourhoods), each carving pulling
! one interior point onto the boundary: the longest edge ab of the current
! polygon is found, the interior points whose angle around the cluster centre
! falls between those of a and b are the candidates, the candidate c closest
! to ab is chosen, and ab is replaced by ac and cb.  The result is a simple,
! generally non-convex polygon that contains every point of the cluster.
! Redundant vertices -- ones lying on the segment between their neighbours --
! are removed at the end.
!
! The file has three parts: the module below, holding the instance type and
! the drawing routines; the main program, which carries the construction; and
! the geometry routines at the bottom.

module polygon_builder
    implicit none

    type :: instance_type
        integer :: npol,nvmax
        character(len=512) :: filename
        character(len=256) :: instname
        integer, allocatable :: nvp(:)
        real(kind=8), allocatable :: vcoor(:,:,:)
    end type instance_type

    ! Set to .true. to trace the construction of every polygon on stdout.
    logical, parameter :: debug = .false.

    ! Output directories, set from the command line by the main program.
    ! Figures are produced only when a plot directory is given.
    character(len=512) :: outdir = '.', plotdir = ''
    logical :: plotfiles = .false.

    ! Tolerance of the collinearity test.
    !
    ! points_colin_2d returns the area of the triangle formed by three points
    ! divided by the area of the equilateral triangle of the same perimeter,
    ! so colin is dimensionless and scale free: it is 0 for collinear points
    ! and 1 for an equilateral triangle.  Testing it against exact zero works
    ! only while the coordinates are integers.  On instances whose
    ! coordinates carry decimals -- the TSPLIB families d*, fl*, u*, sw*,
    ! ts* among them -- three points on a straight line give colin around
    ! 1d-14 rather than 0, and an exact test then leaves redundant vertices
    ! on the polygon boundary.  Worse, a cluster of three nearly collinear
    ! points is not recognised as degenerate and is handed to the convex
    ! hull, where the gift wrapping march cannot close and aborts.
    !
    ! 1d-12 sits far above the noise of the double precision computation and
    ! far below any genuine triangle in these instances.
    real(kind=8), parameter :: colintol = 1.0d-12

    contains

    ! Strips the directory part and the extension of a path, so that
    ! "../inst/momlib/10att48.dat" becomes "10att48".

    function basename_noext(path) result(base)

        implicit none

        character(len=*), intent(in) :: path
        character(len=256) :: base

        integer :: ib,ie

        base = trim(adjustl(path))

        ib = index(base,'/',back=.true.) + 1

        ie = index(base,'.',back=.true.) - 1
        if ( ie .lt. ib ) then
            ie = len_trim(base)
        end if

        base = base(ib:ie)

    end function basename_noext

    subroutine drawallpoints(inst,nvphull,hull)
    
        implicit none
    
        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        
        ! ARRAY ARGUMENTS
        integer, intent(in) :: nvphull(inst%npol)
        real(kind=8), intent(in) :: hull(2,inst%nvmax,inst%npol)
    
        ! This routine must draw the TSPN instances.
    
        ! LOCAL SCALARS
        integer :: i,j,k,inext
        real(kind=8) :: xyamax
    
        ! LOCAL ARRAYS
        character(len=512) :: plotfn
    
        xyamax = - huge( 1.0d0 )
        do k = 1,inst%npol
            do j = 1,inst%nvp(k)
                xyamax = max( xyamax, 1.0d0, abs( inst%vcoor(1,j,k) ), abs( inst%vcoor(2,j,k) ) )
            end do
        end do

        plotfn = trim(adjustl(plotdir))//'/inst-'//trim(inst%instname)//'-allpoints.mp'
                    
        open(unit=1030,file=plotfn)
    
        write(1030,10)
    
        ! Fill the polygons
        do i = 1, inst%npol          ! over the polygons
            write(1030,60)
            do j = 1, nvphull(i)    ! over the vertices of the polygon
                write(1030,40) hull(1,j,i) / xyamax,hull(2,j,i) / xyamax
            end do
            write(1030,70) 'lavanda'
        end do

        ! Draw the polygons
        do i = 1, inst%npol          ! over the polygons
            write(1030,50)
            do j = 1, nvphull(i)    ! over the vertices of the polygon
                write(1030,40) hull(1,j,i) / xyamax,hull(2,j,i) / xyamax
            end do
            write(1030,71) 'black'
        end do

        ! Draw the cluster points
        do i = 1, inst%npol
            do j = 1, inst%nvp(i)
                inext = mod( i, inst%nvp(i) ) + 1
                write(1030,31) inst%vcoor(1:2,j,i) / xyamax,'black'
            end do
        end do

        ! Draw the hull points
        do i = 1, inst%npol
            do j = 1, nvphull(i)
                inext = mod( i, nvphull(i) ) + 1
                write(1030,31) hull(1:2,j,i) / xyamax,'red'
            end do
        end do
    
        write(1030,90)
        close(1030)
    
        ! NON-EXECUTABLE STATEMENTS
    
    ! The lavender used here, (221,180,217), is deliberately a little
    ! darker than the one of the solution figures, (235,200,231). In these
    ! figures the polygons cover about three quarters of the area, against
    ! one quarter in the solution ones, and a large patch of a light colour
    ! looks more washed out than the same colour in small patches surrounded
    ! by white. The darker tone compensates for that, so that the two look
    ! alike on the page. Do not make the two values equal without looking at
    ! the printed result.
        10  format('prologues := 3;',/, &
        'outputtemplate := "%j.mps";',/, &
        'beginfig(1);',/, &
        'u = 8.0cm;',/, &
        'color plum;     plum = (221/255,160/255,221/255);',/, &
        'color Darkmagenta;   Darkmagenta = (139/255,0/255,139/255);',/, &
        'color lilas;    lilas = (220/255,208/255,255/255);',/, &
        'color lavanda;  lavanda = (221/255,180/255,217/255);')
        31 format('fill fullcircle scaled 3pt shifted (',f20.17,'*u,',f20.17,'*u) withcolor',a12,';')
        40 format('( ',f20.10,'u,',f20.10,'u)--')
        50 format('draw')
        60 format('fill')
        70 format('cycle withcolor',a12,';')
        71 format('cycle withpen pencircle scaled 1.0pt withcolor',a12,';')
        90  format('endfig;',/,'end;')
    end subroutine

    subroutine drawpol(inst,nvphull,hull)
    
        implicit none
    
        ! TYPE ARGUMENTS
        type(instance_type), intent(in) :: inst
        
        ! ARRAY ARGUMENTS
        integer, intent(in) :: nvphull(inst%npol)
        real(kind=8), intent(in) :: hull(2,inst%nvmax,inst%npol)
    
        ! This routine must draw the TSPN instances.
    
        ! LOCAL SCALARS
        integer :: i,j,k
        real(kind=8) :: xyamax
    
        ! LOCAL ARRAYS
        character(len=512) :: plotfn
    
        xyamax = - huge( 1.0d0 )
        do k = 1,inst%npol
            do j = 1,inst%nvp(k)
                xyamax = max( xyamax, 1.0d0, abs( inst%vcoor(1,j,k) ), abs( inst%vcoor(2,j,k) ) )
            end do
        end do

        plotfn = trim(adjustl(plotdir))//'/inst-'//trim(inst%instname)//'-tspn.mp'
                    
        open(unit=1030,file=plotfn)
    
        write(1030,10)
    
        ! Fill the polygons
        do i = 1, inst%npol          ! over the polygons
            write(1030,60)
            do j = 1, nvphull(i)     ! over the vertices of the polygon
                write(1030,40) hull(1,j,i) / xyamax,hull(2,j,i) / xyamax
            end do
            write(1030,70) 'lavanda'
        end do

        ! Draw the polygons
        do i = 1, inst%npol          ! over the polygons
            write(1030,50)
            do j = 1, nvphull(i)    ! over the vertices of the polygon
                write(1030,40) hull(1,j,i) / xyamax,hull(2,j,i) / xyamax
            end do
            write(1030,71) 'black'
        end do

        ! Draw the hull points
        do i = 1, inst%npol
            if ( nvphull(i) .eq. 1 ) write(1030,31) hull(1:2,1,i) / xyamax,'black'
        end do
    
        write(1030,90)
        close(1030)
    
        ! NON-EXECUTABLE STATEMENTS
    
        10  format('prologues := 3;',/, &
        'outputtemplate := "%j.mps";',/, &
        'beginfig(1);',/, &
        'u = 8.0cm;',/, &
        'color plum;     plum    = (221/255,160/255,221/255);',/, &
        'color Darkmagenta;   Darkmagenta = (139/255,0/255,139/255);',/, &
        'color lilas;    lilas   = (220/255,208/255,255/255);',/, &
        'color lavanda;  lavanda = (221/255,180/255,217/255);')
        31 format('fill fullcircle scaled 3pt shifted (',f20.17,'*u,',f20.17,'*u) withcolor',a12,';')
        40 format('( ',f20.10,'u,',f20.10,'u)--')
        50 format('draw')
        60 format('fill')
        70 format('cycle withcolor',a12,';')
        71 format('cycle withpen pencircle scaled 1.0pt withcolor',a12,';')
        90  format('endfig;',/,'end;')
    end subroutine
    
end module polygon_builder

! *****************************************************************
! ************************ MAIN PROGRAM ***************************
! *****************************************************************

program stage3_build_polygons 

    use polygon_builder

    implicit none

    ! PARAMETERS
    logical :: inhull

    ! LOCAL SCALARS
    type(instance_type) :: inst
    integer :: allocerr,i,j,kinsert,k,ell,bestedge,jnext,&
    nextbestedge,jbest,jfirst,jlast,kcounter,jnext1,jnext2,remove,nargs
    real(kind=8) :: bestleng,edgelength,dist,bestdist,colin
    logical :: collinear

    ! LOCAL ARRAYS
    integer, allocatable :: hullind(:),nvphull(:),newhullind(:)
    real(kind=8), allocatable :: hull(:,:,:),newhull(:,:,:)
    character(len=512) :: filen
    character(len=32) :: khatstr
    integer :: khatlen,khatstat

    ! Command line: <input.dat> <output-dir> [<plot-dir>]
    ! Both directories must already exist.  MetaPost figures are written
    ! only when a plot directory is given.
    nargs = command_argument_count()

    if ( nargs .lt. 2 .or. nargs .gt. 3 ) then
        write(*,*) 'Usage: stage3_build_polygons <input.dat> <output-dir> [<plot-dir>]'
        stop 1
    end if

    call get_command_argument(1,inst%filename)
    call get_command_argument(2,outdir)

    plotfiles = ( nargs .eq. 3 )

    if ( plotfiles ) then
        call get_command_argument(3,plotdir)
    end if

    inst%instname = basename_noext(inst%filename)
    kinsert = 3
    call get_environment_variable('TSPN_KHAT',khatstr,khatlen,khatstat)
    if ( khatstat .eq. 0 .and. khatlen .gt. 0 ) then
        read(khatstr,*,iostat=khatstat) kinsert
        if ( khatstat .ne. 0 .or. kinsert .lt. 0 ) then
            write(*,*) 'Invalid TSPN_KHAT: ',trim(khatstr)
            stop 1
        end if
    end if

    filen = trim(adjustl(outdir))//'/'//trim(inst%instname)//'.dat'
    open(unit=1050,file=filen)
    write(*,*) trim(filen)

    call InputData(inst)

    allocate(hull(2,inst%nvmax,inst%npol),nvphull(inst%npol),&
    newhull(2,inst%nvmax,inst%npol),stat=allocerr)

    if ( allocerr .ne. 0 ) then
        write(*,*) 'Allocation error - InputData.'
        stop
    end if
        
    do i = 1, inst%npol
        
        if ( debug ) then

            write(*,*) 'Polygon = ',i
            write(*,*) 'Number of original points = ',inst%nvp(i)

            do j = 1, inst%nvp(i)
                write(*,*) inst%vcoor(1:2,j,i)
            end do

            write(*,*) 'Building the convex hull'

        end if
        
        allocate(hullind(inst%nvp(i)),newhullind(inst%nvp(i)),stat=allocerr)
        if ( allocerr .ne. 0 ) then
            write(*,*) 'Allocation error - InputData.'
            stop
        end if

        if ( inst%nvp(i) .eq. 1 ) then
            nvphull(i) = 1
            hullind(1) = 1
        else if ( inst%nvp(i) .eq. 2 ) then
            nvphull(i) = 2
            hullind(1) = 1
            hullind(2) = 2
        else !if ( inst%nvp(i) .gt. 2 ) then
            if ( debug ) then
                write(*,*) 'All the points are collinear?'
            end if
            
            collinear = .true.

            do j = 1, inst%nvp(i)-2

                jnext1 = j+1
                jnext2 = j+2

                if ( inst%vcoor(1,j,i) .eq. inst%vcoor(1,jnext1,i) .and. &
                inst%vcoor(1,jnext1,i) .eq. inst%vcoor(1,jnext2,i) ) then

                    collinear = .true.

                else if ( inst%vcoor(2,j,i) .eq. inst%vcoor(2,jnext1,i) .and. &
                inst%vcoor(2,jnext1,i) .eq. inst%vcoor(2,jnext2,i) ) then

                    collinear = .true.

                else
                    call points_colin_2d(inst%vcoor(1:2,j,i),inst%vcoor(1:2,jnext1,i),&
                    inst%vcoor(1:2,jnext2,i),colin)

                    if ( colin .gt. colintol ) then    ! Are NOT collinear

                        if ( debug ) then
                            write(*,*) 'Not all points are collinear'
                            write(*,*) 'j = ',j,' point = ',inst%vcoor(1:2,j,i)
                            write(*,*) 'jnext1 = ',jnext1,' point = ',inst%vcoor(1:2,jnext1,i)
                            write(*,*) 'jnext2 = ',jnext2,' point = ',inst%vcoor(1:2,jnext2,i)
                        end if
                        
                        collinear = .false.
                        exit

                    end if
                end if
            end do

            if ( collinear ) then

                if ( debug ) then
                    write(*,*) 'nvp(i) = ',inst%nvp(i),' Points are colinear'
                end if
                
                nvphull(i) = 2
                
                bestdist = 0.0d0
                do j = 1, inst%nvp(i)-1
                    do ell = j+1, inst%nvp(i)
                        dist = norm2( inst%vcoor(1:2,j,i) - inst%vcoor(1:2,ell,i) )
                        if ( dist .gt. bestdist ) then
                            bestdist = dist
                            hullind(1) = j
                            hullind(2) = ell
                        end if
                    end do
                end do
            else !collinear = .false.
                call points_hull_2d(inst%nvp(i),inst%vcoor(1:2,1:inst%nvp(i),i),nvphull(i),hullind)
            end if
        end if

        if ( debug ) then
            write(*,*) 'Convex Hull of Polygon = ',i,' Number of original points = ',inst%nvp(i)

            write(*,*) 'Number of hull points = ',nvphull(i)
        end if
        
        do j = 1, nvphull(i)

            if ( debug ) then
                write(*,*) hullind(j),inst%vcoor(1:2,hullind(j),i)
            end if
            
            hull(1:2,j,i) = inst%vcoor(1:2,hullind(j),i)
        end do
        

        if ( nvphull(i) .gt. 2 ) then  ! If nvphull(i) .eq. 2 : the remaining points are collinear and there is no need to insert them again
            
            k = min( kinsert, inst%nvp(i) - nvphull(i) )

            if ( debug ) then
                write(*,*) 'k = ',k
            end if
                            
            if ( k .ge. 1 ) then
                kcounter = 1
                do while ( kcounter .le. k )

                    bestleng = 0.0d0
                
                    do j = 1, nvphull(i)
                        jnext = mod( j, nvphull(i) ) + 1
                        edgelength = norm2( hull(1:2,j,i) - hull(1:2,jnext,i) )

                        if ( edgelength .gt. bestleng ) then

                            if ( .not.( hullind(j) .eq. inst%nvp(i) .and. hullind(jnext) .eq. 1 ) ) then

                                if ( abs( hullind(j) - hullind(jnext) ) .gt. 1 ) then

                                    if ( debug ) then
                                        write(*,*) 'We find a candidate edge'
                                        write(*,*) 'bestleng = ',bestleng
                                    end if
                                    
                                    bestleng = edgelength
                                    bestedge = j    ! Entre hullind(j) e hullind(jnext)
                                    nextbestedge = jnext
                                end if

                            end if
                            
                        end if
                    end do
                    
                    if ( debug ) then
                        write(*,*) 'Best edge to insert, j = ',bestedge,' jnext = ',nextbestedge
                    end if
                    
                    if ( hullind(bestedge) .eq. inst%nvp(i) ) then
                        jfirst = 1
                    else
                        jfirst = hullind(bestedge) + 1
                    end if

                    if ( hullind(nextbestedge) .eq. 1 ) then
                        jlast = inst%nvp(i)
                    else
                        jlast = hullind(nextbestedge)-1
                    end if
                    
                    if ( debug ) then
                        write(*,*) 'Reinsert candidates = ',jfirst,'--',jlast
                    end if
                                            
                    bestdist = huge( 1.0d0 )
                    if ( jfirst .le. jlast ) then

                        do j = jfirst, jlast

                            if ( debug ) then
                                write(*,*) 'j = ',j
                            end if
                            
                            inhull = .false.

                            do ell = 1, nvphull(i)
                                if ( j .eq. hullind(ell)  ) then
                                    inhull = .true.
                                    exit
                                end if
                            end do
                            
                            if ( .not.(inhull) ) then
                                
                                call line_exp_point_dist_2d ( hull(1:2,bestedge,i), hull(1:2,nextbestedge,i), &
                                inst%vcoor(1:2,j,i), dist )        

                                if ( debug ) then
                                    write(*,*) j,inst%vcoor(1:2,j,i), dist
                                end if
                                
                                if ( dist .lt. bestdist ) then
                                    bestdist = dist
                                    jbest = j
                                end if
                            end if
                        end do

                    else

                        do j = jfirst, inst%nvp(i)

                            if ( debug ) then
                                write(*,*) 'j = ',j
                            end if
                            
                            inhull = .false.

                            do ell = 1, nvphull(i)
                                if ( j .eq. hullind(ell)  ) then
                                    inhull = .true.
                                    exit
                                end if
                            end do
                            
                            if ( .not.(inhull) ) then
                                
                                call line_exp_point_dist_2d ( hull(1:2,bestedge,i), hull(1:2,nextbestedge,i), &
                                inst%vcoor(1:2,j,i), dist )        

                                if ( debug ) then
                                    write(*,*) j,inst%vcoor(1:2,j,i), dist    
                                end if
                                                                    
                                if ( dist .lt. bestdist ) then
                                    bestdist = dist
                                    jbest = j
                                end if
                            end if
                            
                        end do

                        do j = 1, jlast

                            if ( debug ) then
                                write(*,*) 'j = ',j
                            end if
                            
                            inhull = .false.

                            do ell = 1, nvphull(i)
                                if ( j .eq. hullind(ell)  ) then
                                    inhull = .true.
                                    exit
                                end if
                            end do
                            
                            if ( .not.(inhull) ) then
                                
                                call line_exp_point_dist_2d ( hull(1:2,bestedge,i), hull(1:2,nextbestedge,i), &
                                inst%vcoor(1:2,j,i), dist )        

                                if ( debug ) then
                                    write(*,*) j,inst%vcoor(1:2,j,i), dist    
                                end if
                                                                    
                                if ( dist .lt. bestdist ) then
                                    bestdist = dist
                                    jbest = j
                                end if
                            end if
                            
                        end do
                    end if
                    
                    if ( debug ) then
                        write(*,*) 'Lets insert de jbest = ',jbest,' between bestedge = ',bestedge,&
                        ' and nextbestedge = ',nextbestedge    
                    end if
                    
                    nvphull(i) = nvphull(i) + 1

                    if ( debug ) then
                        write(*,*) 'New Number of hull points = ',nvphull(i)    
                    end if
                                            
                    if ( nextbestedge .eq. 1 ) then
                        hull(1:2,nvphull(i),i) = inst%vcoor(1:2,jbest,i)
                        hullind(nvphull(i)) = jbest
                    else
                        newhull(1:2,1:bestedge,i) = hull(1:2,1:bestedge,i)
                        newhull(1:2,bestedge+1,i) = inst%vcoor(1:2,jbest,i)
                        newhull(1:2,bestedge+2:nvphull(i),i) = hull(1:2,nextbestedge:nvphull(i)-1,i)
                        hull(1:2,1:nvphull(i),i) = newhull(1:2,1:nvphull(i),i)

                        newhullind(1:nvphull(i)) = (/ hullind(1:bestedge), jbest, hullind(nextbestedge:nvphull(i)-1) /)
                        hullind(1:nvphull(i)) = newhullind(1:nvphull(i))
                    end if
                        
                    if ( debug ) then
                        write(*,*) 'New Convex Hull of Polygon = ',i,' Number of original points = ',inst%nvp(i)

                        write(*,*) 'New Number of hull points = ',nvphull(i)

                        do j = 1, nvphull(i)
                            write(*,*) hullind(j),hull(1:2,j,i)
                        end do    
                    end if
                    
                    kcounter = kcounter + 1
                end do
                
            end if
        end if

        ! In the concave hull, can we eliminate collinear points?
        if ( nvphull(i) .ge. 3 ) then
            do j = 1, nvphull(i)

                if ( j .gt. nvphull(i) ) then
                    exit
                end if

            100 continue
                
                if ( j .eq. nvphull(i) ) then
                    jnext1 = 1
                    jnext2 = 2
                else if ( j .eq. nvphull(i)-1 ) then
                    jnext1 = j+1
                    jnext2 = 1
                else
                    jnext1 = j+1
                    jnext2 = j+2
                end if

                if ( debug ) then
                    write(*,*) 'j = ',j,' point = ',hull(1:2,j,i)
                    write(*,*) 'jnext1 = ',jnext1,' point = ',hull(1:2,jnext1,i)
                    write(*,*) 'jnext2 = ',jnext2,' point = ',hull(1:2,jnext2,i)    
                end if
                
                call points_colin_2d(hull(1:2,j,i),hull(1:2,jnext1,i),&
                hull(1:2,jnext2,i),colin)

                if ( colin .le. colintol ) then    ! Are collinear
                    if ( debug ) then
                        write(*,*) 'nvphull(i) = ',nvphull(i),' Yes, points are colinear'    
                    end if
                    
                    nvphull(i) = nvphull(i) - 1

                    bestdist = norm2( hull(1:2,j,i) - hull(1:2,jnext1,i) )
                    remove = jnext2

                    dist = norm2( hull(1:2,j,i) - hull(1:2,jnext2,i) )
                    if ( dist .gt. bestdist ) then
                        bestdist = dist
                        remove = jnext1
                    end if

                    dist = norm2( hull(1:2,jnext1,i) - hull(1:2,jnext2,i) )
                    if ( dist .gt. bestdist ) then
                        bestdist = dist
                        remove = j
                    end if

                    if ( debug ) then
                        write(*,*) 'remove = ',remove    
                    end if
                    
                    hull(1:2,remove:nvphull(i),i) = hull(1:2,remove+1:nvphull(i)+1,i)

                    if ( debug ) then
                        write(*,*) 'New number of points = ',nvphull(i)   

                        do ell = 1, nvphull(i)
                            write(*,*) hull(1:2,ell,i)
                        end do
                    end if
                    
                    if ( nvphull(i) .lt. 3 ) then
                        exit
                    end if

                    go to 100
                end if
            end do
        end if

        
        deallocate(hullind,newhullind,stat=allocerr)
        if ( allocerr .ne. 0 ) then
            write(*,*) 'Deallocation error - Main.'
            stop
        end if

    end do

    ! Write the instance: the number of polygons and the size of the largest,
    ! then each polygon as its vertex count followed by its vertices.
    write(1050,*) inst%npol,maxval( nvphull(1:inst%npol) )

    do i = 1, inst%npol
        write(1050,*) nvphull(i)

        do j = 1, nvphull(i)
            write(1050,*) hull(1:2,j,i)
        end do
    end do

    close(1050)

    if ( plotfiles ) then
        call drawallpoints(inst,nvphull,hull)
        call drawpol(inst,nvphull,hull)
    end if

    deallocate(hull,newhull,nvphull,stat=allocerr)
    if ( allocerr .ne. 0 ) then
        write(*,*) 'Deallocation error - Main.'
        stop
    end if

    stop

    contains

    subroutine InputData(inst)
        
        implicit none

        ! TYPE ARGUMENTS
        type(instance_type), intent(inout) :: inst
        
        ! This routine obtains the input data.

        ! LOCAL SCALARS
        integer :: i,j,allocerr

        open(unit=10,file=trim(adjustl(inst%filename)))
        
        read(10,*) inst%npol,inst%nvmax

        allocate(inst%nvp(inst%npol),inst%vcoor(2,inst%nvmax,inst%npol)&
        ,stat=allocerr)

        if ( allocerr .ne. 0 ) then
            write(*,*) 'Allocation error - InputData.'
            stop
        end if

        do i = 1,inst%npol
            read(10,*) inst%nvp(i)

            do j = 1,inst%nvp(i)
                read(10,*) inst%vcoor(1:2,j,i)
            end do
        end do

        close(10)

    end subroutine InputData

end program stage3_build_polygons

! *****************************************************************
! ********************* GEOMETRY ROUTINES *************************
! *****************************************************************
!
! Convex hull and geometric predicates, by John Burkardt, distributed
! under the GNU LGPL license.

subroutine points_hull_2d ( node_num, node_xy, hull_num, hull )

    ! POINTS_HULL_2D computes the convex hull of 2D points.
    !
    !   The work involved is N*log(H), where N is the number of points, and H is
    !   the number of points that are on the hull.
    !
    !   Input:
    !     integer ( kind = 4 ) NODE_NUM, the number of nodes.
    !     real ( kind = 8 ) NODE_XY(2,NODE_NUM), the coordinates of the nodes.
    !
    !   Output:
    !     integer ( kind = 4 ) HULL_NUM, the number of nodes that lie on
    !     the convex hull.
    !     integer ( kind = 4 ) HULL(NODE_NUM).  Entries 1 through HULL_NUM
    !     contain the indices of the nodes that form the convex hull, in order.
    !
    !   Author: John Burkardt.  This code is distributed under the GNU LGPL license.

    implicit none

    integer ( kind = 4 ) node_num

    real ( kind = 8 ) angle
    real ( kind = 8 ) angle_max
    real ( kind = 8 ) angle_rad_2d
    real ( kind = 8 ) di
    real ( kind = 8 ) dr
    integer ( kind = 4 ) first
    integer ( kind = 4 ) hull(node_num)
    integer ( kind = 4 ) hull_num
    integer ( kind = 4 ) i
    real ( kind = 8 ) node_xy(2,node_num)
    real ( kind = 8 ) p_xy(2)
    integer ( kind = 4 ) q
    real ( kind = 8 ) q_xy(2)
    integer ( kind = 4 ) r
    real ( kind = 8 ) r_xy(2)

    if ( node_num < 1 ) then
        hull_num = 0
        return
    end if
    !
    !  If NODE_NUM = 1, the hull is the point.
    !
    if ( node_num == 1 ) then
        hull_num = 1
        hull(1) = 1
        return
    end if
    !
    !  If NODE_NUM = 2, then the convex hull is either the two distinct points,
    !  or possibly a single (repeated) point.
    !
    if ( node_num == 2 ) then

        if ( node_xy(1,1) /= node_xy(1,2) .or. node_xy(2,1) /= node_xy(2,2) ) then
            hull_num = 2
            hull(1) = 1
            hull(2) = 2
        else
            hull_num = 1
            hull(1) = 1
        end if

        return

    end if
    !
    !  Find the leftmost point and call it "Q".
    !  In case of ties, take the bottom-most.
    !
    q = 1
    do i = 2, node_num
        if ( node_xy(1,i) < node_xy(1,q) .or. &
        ( node_xy(1,i) == node_xy(1,q) .and. node_xy(2,i) < node_xy(2,q) ) ) then
            q = i
        end if
    end do

    q_xy(1:2) = node_xy(1:2,q)
    !
    !  Remember the starting point, so we know when to stop!
    !
    first = q
    hull_num = 1
    hull(1) = q
    !
    !  For the first point, make a dummy previous point, 1 unit south,
    !  and call it "P".
    !
    p_xy(1) = q_xy(1)
    p_xy(2) = q_xy(2) - 1.0D+00
    !
    !  Now, having old point P, and current point Q, find the new point R
    !  so the angle PQR is maximal.
    !
    !  Watch out for the possibility that the two nodes are identical.
    !
    do

        r = 0
        angle_max = 0.0D+00

        do i = 1, node_num

            if ( i /= q .and. &
            ( node_xy(1,i) /= q_xy(1) .or. node_xy(2,i) /= q_xy(2) ) ) then

                angle = angle_rad_2d ( p_xy, q_xy, node_xy(1:2,i) )

                if ( r == 0 .or. angle_max < angle ) then

                    r = i
                    r_xy(1:2) = node_xy(1:2,r)
                    angle_max = angle
                !
                !  In case of ties, choose the nearer point.
                !
                else if ( r /= 0 .and. angle == angle_max ) then

                    di = ( node_xy(1,i) - q_xy(1) )**2 + ( node_xy(2,i) - q_xy(2) )**2
                    dr = ( r_xy(1)      - q_xy(1) )**2 + ( r_xy(2)      - q_xy(2) )**2

                    if ( di < dr ) then
                        r = i
                        r_xy(1:2) = node_xy(1:2,r)
                        angle_max = angle
                    end if

                end if

            end if

        end do
    !
    !  We are done when we have returned to the first point on the convex hull.
    !
        if ( r == first ) then
            exit
        end if

        hull_num = hull_num + 1

        if ( node_num < hull_num ) then
            write ( *, '(a)' ) ' '
            write ( *, '(a)' ) 'POINTS_HULL_2D - Fatal error!'
            write ( *, '(a)' ) '  The algorithm has failed.'
            stop 1
        end if
    !
    !  Add point R to convex hull.
    !
        hull(hull_num) = r
    !
    !  Set P := Q, Q := R, and prepare to search for next point R.
    !
        q = r

        p_xy(1:2) = q_xy(1:2)
        q_xy(1:2) = r_xy(1:2)

    end do

    return
end

function angle_rad_2d ( p1, p2, p3 )

    ! ANGLE_RAD_2D returns the angle in radians swept out between two rays in 2D.
    !
    !   Except for the zero angle case, it should be true that
    !   ANGLE_RAD_2D ( P1, P2, P3 ) + ANGLE_RAD_2D ( P3, P2, P1 ) = 2 * PI
    !   P1
    !   /
    !   /
    !   /
    !   /
    !   P2--------->P3
    !
    !   Input:
    !     real ( kind = 8 ) P1(2), P2(2), P3(2), define the rays
    !     P1 - P2 and P3 - P2 which define the angle.
    !
    !   Output:
    !     real ( kind = 8 ) ANGLE_RAD_2D, the angle swept out by the rays,
    !     in radians.  0 <= ANGLE_RAD_2D < 2 * PI.  If either ray has zero
    !     length, then ANGLE_RAD_2D is set to 0.
    !
    !   Author: John Burkardt.  This code is distributed under the GNU LGPL license.

    implicit none

    real ( kind = 8 ) angle_rad_2d
    real ( kind = 8 ) p(2)
    real ( kind = 8 ) p1(2)
    real ( kind = 8 ) p2(2)
    real ( kind = 8 ) p3(2)
    real ( kind = 8 ), parameter :: r8_pi = 3.141592653589793D+00

    p(1) = ( p3(1) - p2(1) ) * ( p1(1) - p2(1) ) &
        + ( p3(2) - p2(2) ) * ( p1(2) - p2(2) )

    p(2) = ( p3(1) - p2(1) ) * ( p1(2) - p2(2) ) &
        - ( p3(2) - p2(2) ) * ( p1(1) - p2(1) )

    if ( all ( p(1:2) == 0.0D+00)  ) then
        angle_rad_2d = 0.0D+00
        return
    end if

    angle_rad_2d = atan2 ( p(2), p(1) )

    if ( angle_rad_2d < 0.0D+00 ) then
        angle_rad_2d = angle_rad_2d + 2.0D+00 * r8_pi
    end if

    return
end

subroutine line_exp_point_dist_2d ( p1, p2, p, dist )

    ! LINE_EXP_POINT_DIST_2D: distance ( explicit line, point ) in 2D.
    !
    !   The explicit form of a line in 2D is:
    !   the line through the points P1 and P2.
    !
    !   Parameters:
    !     Input, real ( kind = 8 ) P1(2), P2(2), two points on the line.
    !     Input, real ( kind = 8 ) P(2), the point whose distance from the line is
    !     to be measured.
    !     Output, real ( kind = 8 ) DIST, the distance from the point to the line.
    !
    !   Author: John Burkardt.  This code is distributed under the GNU LGPL license.

    implicit none

    integer ( kind = 4 ), parameter :: dim_num = 2

    real ( kind = 8 ) bot
    real ( kind = 8 ) dist
    real ( kind = 8 ) dot
    logical ( kind = 4 ) line_exp_is_degenerate_nd
    real ( kind = 8 ) p(dim_num)
    real ( kind = 8 ) p1(dim_num)
    real ( kind = 8 ) p2(dim_num)
    real ( kind = 8 ) pn(dim_num)
    real ( kind = 8 ) t

    if ( line_exp_is_degenerate_nd ( dim_num, p1, p2 ) ) then

        pn(1:dim_num) = p1(1:dim_num)
    !
    !  (P-P1) dot (P2-P1) = Norm(P-P1) * Norm(P2-P1) * Cos(Theta).
    !
    !  (P-P1) dot (P2-P1) / Norm(P-P1)^2 = normalized coordinate T
    !  of the projection of (P-P1) onto (P2-P1).
    !
    else

        dot = sum ( ( p(1:dim_num) - p1(1:dim_num) ) &
                * ( p2(1:dim_num) - p1(1:dim_num) ) )

        bot = sum ( ( p2(1:dim_num) - p1(1:dim_num) )**2 )

        t = dot / bot

        pn(1:dim_num) = p1(1:dim_num) + t * ( p2(1:dim_num) - p1(1:dim_num) )

    end if

    dist = sqrt ( sum ( ( p(1:dim_num) - pn(1:dim_num) )**2 ) )

    return
end

function line_exp_is_degenerate_nd ( dim_num, p1, p2 )

    ! LINE_EXP_IS_DEGENERATE_ND finds if an explicit line is degenerate in ND.
    !
    !   The explicit form of a line in ND is:
    !   the line through the points P1 and P2.
    !   An explicit line is degenerate if the two defining points are equal.
    !
    !   Parameters:
    !     Input, integer ( kind = 4 ) DIM_NUM, the spatial dimension.
    !     Input, real ( kind = 8 ) P1(DIM_NUM), P2(DIM_NUM), two points on the line.
    !     Output, logical ( kind = 4 ) LINE_EXP_IS_DEGENERATE_ND, is TRUE if the line
    !     is degenerate.
    !
    !   Author: John Burkardt.  This code is distributed under the GNU LGPL license.

    implicit none

    integer ( kind = 4 ) dim_num

    logical ( kind = 4 ) line_exp_is_degenerate_nd
    real ( kind = 8 ) p1(dim_num)
    real ( kind = 8 ) p2(dim_num)

    line_exp_is_degenerate_nd = ( all ( p1(1:dim_num) == p2(1:dim_num) ) )

    return
end

subroutine points_colin_2d ( p1, p2, p3, colin )

    ! POINTS_COLIN_2D estimates the colinearity of 3 points in 2D.
    !
    !   The estimate of colinearity that is returned is the ratio
    !   of the area of the triangle spanned by the points to the area
    !   of the equilateral triangle with the same perimeter.
    !   This estimate is 1 if the points are maximally noncolinear, 0 if the
    !   points are exactly colinear, and otherwise is closer to 1 or 0 depending
    !   on whether the points are far or close to colinearity.
    !
    !   Parameters:
    !     Input, real ( kind = 8 ) P1(2), P2(2), P3(2), the points.
    !     Output, real ( kind = 8 ) COLIN, the colinearity estimate.
    !
    !   Author: John Burkardt.  This code is distributed under the GNU LGPL license.

    implicit none

    integer ( kind = 4 ), parameter :: dim_num = 2

    real ( kind = 8 ) area_triangle
    real ( kind = 8 ) area2
    real ( kind = 8 ) colin
    real ( kind = 8 ) p1(dim_num)
    real ( kind = 8 ) p2(dim_num)
    real ( kind = 8 ) p3(dim_num)
    real ( kind = 8 ) perim
    real ( kind = 8 ) side
    real ( kind = 8 ) t(dim_num,3)

    t(1:dim_num,1:3) = reshape ( (/ &
        p1(1:dim_num), p2(1:dim_num), p3(1:dim_num) /), (/ dim_num, 3 /) )

    call triangle_area_2d ( t, area_triangle )

    if ( area_triangle == 0.0D+00 ) then

        colin = 0.0D+00

    else

        perim = sqrt ( sum ( ( p2(1:dim_num) - p1(1:dim_num) )**2 ) ) &
            + sqrt ( sum ( ( p3(1:dim_num) - p2(1:dim_num) )**2 ) ) &
            + sqrt ( sum ( ( p1(1:dim_num) - p3(1:dim_num) )**2 ) )

        side = perim / 3.0D+00

        area2 = 0.25D+00 * sqrt ( 3.0D+00 ) * side * side

        colin = abs ( area_triangle ) / area2

    end if

    return
end

subroutine triangle_area_2d ( t, area )

    ! TRIANGLE_AREA_2D computes the area of a triangle in 2D.
    !
    !   If the triangle's vertices are given in counter clockwise order,
    !   the area will be positive.  If the triangle's vertices are given
    !   in clockwise order, the area will be negative!
    !   An earlier version of this routine always returned the absolute
    !   value of the computed area.  I am convinced now that that is
    !   a less useful result!  For instance, by returning the signed
    !   area of a triangle, it is possible to easily compute the area
    !   of a nonconvex polygon as the sum of the (possibly negative)
    !   areas of triangles formed by node 1 and successive pairs of vertices.
    !
    !   Parameters:
    !     Input, real ( kind = 8 ) T(2,3), the triangle vertices.
    !     Output, real ( kind = 8 ) AREA, the area of the triangle.
    !
    !   Author: John Burkardt.  This code is distributed under the GNU LGPL license.

    implicit none

    integer ( kind = 4 ), parameter :: dim_num = 2

    real ( kind = 8 ) area
    real ( kind = 8 ) t(dim_num,3)

    area = 0.5D+00 * ( &
        t(1,1) * ( t(2,2) - t(2,3) ) &
        + t(1,2) * ( t(2,3) - t(2,1) ) &
        + t(1,3) * ( t(2,1) - t(2,2) ) )

    return
end