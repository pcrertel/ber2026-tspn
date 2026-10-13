! Generator of the calibration set: random TSPN instances with polygonal
! neighbourhoods, for tuning the parameters of a metaheuristic without
! training on the instances the method will be measured on.
!
! Rather than imitating the appearance of the converted instances, it replays
! the pipeline that produced them from the GTSP-Lib and the MOM-Lib:
!
!   points of a cluster
!     -> counterclockwise angular sort around the centroid   (stage 2)
!     -> convex hull                                         (stage 3)
!     -> reinsertion of up to kinsert = 3 points on the       (stage 3)
!        longest eligible edges, each creating a reflex vertex
!
! Usage:
!     generate_calibration <cluster-profiles.dat> <output-dir>
!     generate_calibration <cluster-profiles.dat> <output-dir> \
!                          <per-npol> <root-seed> <name-tag>
!
! The first form reproduces the calibration set: the design below,
! 80 instances named <npol>rnd<NN>.dat.  The second draws a set with the same
! design but a fixed number of instances for each npol, a different root seed
! and a different infix in the file names -- which is how the disjoint test
! set is produced, to check the elite configurations a tuner returns against
! instances it never trained on.
!
! The points of a cluster are drawn uniformly in the Voronoi cell of its
! centre, so that the neighbourhoods tile the domain without invading one
! another, the way real spatial clusters do.  Only the CLUSTER SIZES come
! from the converted instances, resampled from the profiles file; every
! coordinate is new.
!
! The run is deterministic: each instance gets its own seed derived from a
! fixed root, so any single instance can be reproduced on its own.

module calibration_generator

    implicit none

    ! PARAMETERS
    integer, parameter :: kinsert = 3    ! points reinserted per polygon
    integer, parameter :: ncand   = 10   ! candidates per centre (blue noise)
    integer, parameter :: kviz    = 12   ! neighbours in the Voronoi test
    real(kind=8), parameter :: pi = acos( -1.0d0 )

    ! State of the random number generator
    real(kind=8) :: rngix

contains

    real(kind=8) function drand(ix)

        ! Schrage's generator, the same one stage 2 of the converter uses:
        !
        ! L. Schrage, A more portable Fortran random number generator, ACM
        ! Transactions on Mathematical Software 5 (1979), 132-138.

        implicit none

        real(kind=8), intent(inout) :: ix

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

    integer function randint(n)

        ! Uniform integer in 0..n-1

        implicit none
        integer, intent(in) :: n

        randint = int( drand(rngix) * dble(n) )
        if ( randint .ge. n ) randint = n - 1
        if ( randint .lt. 0 ) randint = 0

        return

    end function randint

    subroutine dist_linha(x1,y1,x2,y2,px,py,dist)

        ! Distance from a point to the LINE through (x1,y1) and (x2,y2).
        ! Equivalent to line_exp_point_dist_2d of stage 3: the projection is
        ! NOT clamped to the segment.

        implicit none
        real(kind=8), intent(in)  :: x1,y1,x2,y2,px,py
        real(kind=8), intent(out) :: dist

        real(kind=8) :: dx,dy,bot,t,nx,ny

        dx = x2 - x1
        dy = y2 - y1
        bot = dx*dx + dy*dy

        if ( bot .le. 0.0d0 ) then
            dist = sqrt( (px-x1)**2 + (py-y1)**2 )
            return
        end if

        t = ( (px-x1)*dx + (py-y1)*dy ) / bot
        nx = x1 + t*dx
        ny = y1 + t*dy
        dist = sqrt( (px-nx)**2 + (py-ny)**2 )

        return

    end subroutine dist_linha

    subroutine ordena_chave(n,chave,ordem)

        ! STABLE insertion sort by increasing key.
        !
        ! Stability is the tie-breaking rule: points sharing a key keep the
        ! order in which they were drawn.  This matters.  Two points of a
        ! cluster can be exactly collinear with its centroid and so share an
        ! angle, and the order chosen for them decides which simple polygon
        ! the hull walk produces -- the alternatives are not equivalent, they
        ! can enclose different areas.  Fixing the rule here is what makes
        ! the generated set reproducible.

        implicit none
        integer, intent(in)  :: n
        real(kind=8), intent(in)  :: chave(n)
        integer, intent(out) :: ordem(n)

        integer :: i,j,tmp

        do i = 1,n
            ordem(i) = i
        end do

        do i = 2,n
            tmp = ordem(i)
            j = i - 1
            do while ( j .ge. 1 )
                if ( chave(ordem(j)) .gt. chave(tmp) ) then
                    ordem(j+1) = ordem(j)
                    j = j - 1
                else
                    exit
                end if
            end do
            ordem(j+1) = tmp
        end do

        return

    end subroutine ordena_chave

    subroutine ordena_xy(n,x,y,ordem)

        ! STABLE insertion sort by increasing (x,y) -- the presort of the
        ! monotone chain algorithm.

        implicit none
        integer, intent(in)  :: n
        real(kind=8), intent(in)  :: x(n),y(n)
        integer, intent(out) :: ordem(n)

        integer :: i,j,tmp
        logical :: maior

        do i = 1,n
            ordem(i) = i
        end do

        do i = 2,n
            tmp = ordem(i)
            j = i - 1
            do while ( j .ge. 1 )
                maior = ( x(ordem(j)) .gt. x(tmp) ) .or. &
                        ( x(ordem(j)) .eq. x(tmp) .and. y(ordem(j)) .gt. y(tmp) )
                if ( maior ) then
                    ordem(j+1) = ordem(j)
                    j = j - 1
                else
                    exit
                end if
            end do
            ordem(j+1) = tmp
        end do

        return

    end subroutine ordena_xy

    subroutine fecho_convexo(m,x,y,nh,hind)

        ! Convex hull by Andrew's monotone chain algorithm.  Returns the
        ! indices of the hull vertices in INCREASING order.  Because the
        ! points arrive sorted by angle around an interior point, that
        ! increasing order coincides with the counterclockwise order along
        ! the boundary -- the property the reinsertion below relies on to
        ! find the discarded points belonging to each edge.

        implicit none
        integer, intent(in)  :: m
        real(kind=8), intent(in)  :: x(m),y(m)
        integer, intent(out) :: nh
        integer, intent(out) :: hind(m)

        integer :: ord(m),lo(m+1),up(m+1),nlo,nup,i,p,tmp,a,b
        real(kind=8) :: cr

        call ordena_xy(m,x,y,ord)

        nlo = 0
        do i = 1,m
            p = ord(i)
            do while ( nlo .ge. 2 )
                a = lo(nlo-1); b = lo(nlo)
                cr = ( x(b)-x(a) )*( y(p)-y(a) ) - ( y(b)-y(a) )*( x(p)-x(a) )
                if ( cr .le. 0.0d0 ) then
                    nlo = nlo - 1
                else
                    exit
                end if
            end do
            nlo = nlo + 1
            lo(nlo) = p
        end do

        nup = 0
        do i = m,1,-1
            p = ord(i)
            do while ( nup .ge. 2 )
                a = up(nup-1); b = up(nup)
                cr = ( x(b)-x(a) )*( y(p)-y(a) ) - ( y(b)-y(a) )*( x(p)-x(a) )
                if ( cr .le. 0.0d0 ) then
                    nup = nup - 1
                else
                    exit
                end if
            end do
            nup = nup + 1
            up(nup) = p
        end do

        nh = 0
        do i = 1,nlo-1
            nh = nh + 1
            hind(nh) = lo(i)
        end do
        do i = 1,nup-1
            nh = nh + 1
            hind(nh) = up(i)
        end do

        ! increasing order of the indices
        do i = 2,nh
            tmp = hind(i)
            p = i - 1
            do while ( p .ge. 1 )
                if ( hind(p) .gt. tmp ) then
                    hind(p+1) = hind(p)
                    p = p - 1
                else
                    exit
                end if
            end do
            hind(p+1) = tmp
        end do

        return

    end subroutine fecho_convexo

    subroutine reinsere(m,x,y,nh,hind,kins)

        ! Reinsertion of up to kins points, replaying stage 3: each step
        ! takes the longest ELIGIBLE edge -- one that skips at least one
        ! original index -- and inserts into it, between its two endpoints,
        ! the discarded point closest to the supporting line.  Every
        ! insertion creates one reflex vertex, which is why no polygon ends
        ! up with more than kins of them.

        implicit none
        integer, intent(in)    :: m,kins
        real(kind=8), intent(in)    :: x(m),y(m)
        integer, intent(inout) :: nh
        integer, intent(inout) :: hind(m)

        integer :: k,it,j,jn,a,b,bestedge,jfirst,jlast,jbest,t,nc,ell
        integer :: cand(m)
        real(kind=8) :: bestleng,leng,bestdist,dist
        logical :: inhull

        k = min( kins, m - nh )
        if ( nh .le. 2 .or. k .lt. 1 ) return

        do it = 1,k

            bestleng = 0.0d0
            bestedge = -1

            do j = 1,nh
                jn = mod( j, nh ) + 1
                a = hind(j); b = hind(jn)
                leng = sqrt( ( x(a)-x(b) )**2 + ( y(a)-y(b) )**2 )
                if ( leng .gt. bestleng ) then
                    if ( .not.( a .eq. m .and. b .eq. 1 ) ) then
                        if ( abs( a - b ) .gt. 1 ) then
                            bestleng = leng
                            bestedge = j
                        end if
                    end if
                end if
            end do

            if ( bestedge .lt. 0 ) exit

            jn = mod( bestedge, nh ) + 1
            a = hind(bestedge); b = hind(jn)

            if ( a .eq. m ) then
                jfirst = 1
            else
                jfirst = a + 1
            end if

            if ( b .eq. 1 ) then
                jlast = m
            else
                jlast = b - 1
            end if

            nc = 0
            if ( jfirst .le. jlast ) then
                do j = jfirst,jlast
                    nc = nc + 1; cand(nc) = j
                end do
            else
                do j = jfirst,m
                    nc = nc + 1; cand(nc) = j
                end do
                do j = 1,jlast
                    nc = nc + 1; cand(nc) = j
                end do
            end if

            bestdist = huge( 1.0d0 )
            jbest = -1

            do t = 1,nc
                j = cand(t)
                inhull = .false.
                do ell = 1,nh
                    if ( hind(ell) .eq. j ) then
                        inhull = .true.
                        exit
                    end if
                end do
                if ( inhull ) cycle
                call dist_linha( x(a),y(a),x(b),y(b),x(j),y(j),dist )
                if ( dist .lt. bestdist ) then
                    bestdist = dist
                    jbest = j
                end if
            end do

            if ( jbest .lt. 0 ) exit

            do ell = nh,bestedge+1,-1
                hind(ell+1) = hind(ell)
            end do
            hind(bestedge+1) = jbest
            nh = nh + 1

        end do

        return

    end subroutine reinsere

end module calibration_generator

program generate_calibration

    use calibration_generator

    implicit none

    ! GENERATION PARAMETERS
    !
    ! Instances are grouped by npol, with an unequal number of instances in
    ! each group: the sampling effort follows
    ! the variance between configurations, not the size of the group.  Below
    ! npol = 50 configurations barely separate, so those values of npol get 5
    ! instances each -- kept rather than dropped, so that a configuration
    ! which degrades on easy instances still shows up.  The values of npol
    ! npol >= 50, where the differences concentrate, get 10 each.
    integer, parameter :: nalvos = 10
    integer, parameter :: alvos(nalvos)   = (/ 10, 20, 30, 40, 50, &
                                               60, 70, 80, 90, 100 /)
    integer, parameter :: quantos(nalvos) = (/  5,  5,  5,  5, 10, &
                                               10, 10, 10, 10,  10 /)
    integer, parameter :: escalas10(10) = (/ 200, 200, 2000, 2000, 2000, &
                                             2000, 20000, 20000, 20000, 200000 /)
    integer, parameter :: escalas5(5)   = (/ 200, 2000, 2000, 20000, 200000 /)
    ! Used only for a set generated with an explicit number of instances per
    ! npol: one domain scale per order of magnitude, so that every value of
    ! npol covers the whole range whatever the number of instances.
    integer, parameter :: escalas4(4)   = (/ 200, 2000, 20000, 200000 /)
    real(kind=8), parameter :: jitter = 0.10d0
    integer(kind=8), parameter :: seedinit = 1234567_8
    integer, parameter :: maxperf = 500, maxnpol = 200

    ! Set from the command line; both directories must already exist.
    character(len=512) :: arqperfis, outdir

    ! Optional command line settings.  With their defaults the program
    ! reproduces the calibration set exactly; overriding them is how a
    ! disjoint set -- a test set for irace, say -- is drawn from the same
    ! design with a different stream of random numbers.
    integer :: nper = 0                        ! 0 = the design above
    integer(kind=8) :: seedroot = seedinit     ! root of the per-instance seeds
    character(len=16) :: tag = 'rnd'           ! infix of the file names

    ! LOCAL SCALARS AND ARRAYS
    integer :: nperf,i,j,ia,idx,np,ndoa,esc,d,jf,rf,tmp,nvmaxi,allocerr,mmax,np2
    integer :: lo,hi,lenb,base(maxnpol),nargs,nthis
    integer(kind=8) :: sem
    integer :: perfnp(maxperf),perftam(maxperf,maxnpol)
    integer :: idoa(maxperf)
    integer :: tam(maxnpol),nvp(maxnpol)
    character(len=80) :: perfnome(maxperf),nomearq
    character(len=8000) :: linha
    real(kind=8), allocatable :: vcoor(:,:,:)

    nargs = command_argument_count()

    if ( nargs .ne. 2 .and. nargs .ne. 5 ) then
        write(*,*) 'Usage: generate_calibration <cluster-profiles.dat> <output-dir>'
        write(*,*) '       generate_calibration <cluster-profiles.dat> <output-dir> ', &
                   '<per-npol> <root-seed> <name-tag>'
        stop 1
    end if

    call get_command_argument(1,arqperfis)
    call get_command_argument(2,outdir)

    if ( nargs .eq. 5 ) then
        call get_command_argument(3,linha)
        read(linha,*) nper
        call get_command_argument(4,linha)
        read(linha,*) seedroot
        call get_command_argument(5,tag)

        if ( nper .lt. 1 ) then
            write(*,*) 'The number of instances for each npol must be at least 1.'
            stop 1
        end if
    end if

    ! ---------------------------------------------------------------------
    ! Read the donor profiles: each line carries npol, the name of the
    ! converted instance it came from, and the sizes of its clusters.  Only
    ! those SIZES are reused; every coordinate generated below is new.
    ! ---------------------------------------------------------------------
    open(unit=1010,file=trim(adjustl(arqperfis)),status='old',err=900)
    nperf = 0
    do
        read(1010,'(A)',end=100) linha
        if ( len_trim(linha) .eq. 0 ) cycle
        nperf = nperf + 1
        ! Two internal reads: the first fixes npol, the second uses it as
        ! the bound of the implied loop.
        read(linha,*) perfnp(nperf)
        read(linha,*) np2,perfnome(nperf), &
                      ( perftam(nperf,j), j = 1,perfnp(nperf) )
    end do
100 continue
    close(1010)
    write(*,*) 'Donor profiles read: ',nperf

    mmax = 0
    do i = 1,nperf
        do j = 1,perfnp(i)
            if ( perftam(i,j) .gt. mmax ) mmax = perftam(i,j)
        end do
    end do

    allocate(vcoor(2,mmax+kinsert,maxnpol),stat=allocerr)
    if ( allocerr .ne. 0 ) then
        write(*,*) 'Allocation error.'
        stop
    end if

    do ia = 1,nalvos
        np = alvos(ia)

        ! Donors: converted instances whose npol falls in
        ! the window [0.8P ; 1.3P].  npol = 30, 40, 60, 70, 80 and 90 do not
        ! occur, or barely occur, among the converted instances, and the
        ! window secures a donor set from the same cluster-size regime --
        ! mean cluster size depends strongly on npol, from about 65 points
        ! per cluster at npol ~ 10 down to 13.6 at npol ~ 100.
        ! The arithmetic is integer on purpose, so the bounds of the window
        ! do not depend on floating point rounding.
        lo = ( 8*np ) / 10
        hi = ( 13*np ) / 10

        ndoa = 0
        do i = 1,nperf
            if ( perfnp(i) .ge. lo .and. perfnp(i) .le. hi ) then
                ndoa = ndoa + 1
                idoa(ndoa) = i
            end if
        end do

        if ( nper .gt. 0 ) then
            nthis = nper
        else
            nthis = quantos(ia)
        end if

        do idx = 1,nthis

            ! deterministic seed: every instance is reproducible on its own
            sem = mod( seedroot + 7919_8*int(np,8) + 104729_8*int(idx,8), 2147483647_8 )
            if ( sem .le. 0_8 ) sem = sem + 2147483646_8
            rngix = dble( sem )

            if ( nper .gt. 0 ) then
                esc = escalas4( mod( idx-1, 4 ) + 1 )
            else if ( quantos(ia) .eq. 5 ) then
                esc = escalas5( mod( idx-1, 5 ) + 1 )
            else
                esc = escalas10( mod( idx-1, 10 ) + 1 )
            end if

            d = idoa( randint(ndoa) + 1 )

            ! shuffle the donor's cluster sizes (Fisher-Yates, same RNG)
            lenb = perfnp(d)
            do j = 1,lenb
                base(j) = perftam(d,j)
            end do
            do jf = lenb,2,-1
                rf = randint(jf) + 1
                tmp = base(jf); base(jf) = base(rf); base(rf) = tmp
            end do

            ! fit the length to the target npol: truncate if the donor has
            ! too many clusters, cycle through it if it has too few
            do j = 1,np
                tam(j) = base( mod( j-1, lenb ) + 1 )
            end do


            call gera_instancia(np,tam,dble(esc),jitter,mmax,nvp,vcoor,nvmaxi)

            write(nomearq,'(I0,A,I2.2,A)') np,trim(adjustl(tag)),idx,'.dat'
            open(unit=1050,file=trim(adjustl(outdir))//'/'//trim(adjustl(nomearq)),err=910)
            write(1050,*) np,nvmaxi
            do i = 1,np
                write(1050,*) nvp(i)
                do j = 1,nvp(i)
                    write(1050,*) vcoor(1:2,j,i)
                end do
            end do
            close(1050)

            write(*,'(A,A,A,I4,A,I3,A,I7,A,I11)') '  ',trim(adjustl(nomearq)), &
            '  npol=',np,'  nvmax=',nvmaxi,'  domain=',esc,'  seed=',sem

        end do
    end do

    deallocate(vcoor)

    stop

900 continue
    write(*,*) 'Could not open the profiles file: ',trim(adjustl(arqperfis))
    stop 1

910 continue
    write(*,*) 'Could not write into: ',trim(adjustl(outdir))
    write(*,*) 'Does the output directory exist?'
    stop 1

contains

    subroutine gera_instancia(npol,tam,dom,jit,mmax,nvp,vcoor,nvmaxi)

        implicit none

        integer, intent(in)  :: npol,mmax
        integer, intent(in)  :: tam(npol)
        real(kind=8), intent(in)  :: dom,jit
        integer, intent(out) :: nvp(npol),nvmaxi
        real(kind=8), intent(out) :: vcoor(2,mmax+kinsert,npol)

        integer :: i,j,c,t,a,b,ell,m,mm,nh,tent,maxtent,kk
        integer :: viz(kviz,npol),idd(npol),ordem(mmax),hind(mmax)
        real(kind=8) :: cx(npol),cy(npol),nn(npol),rlim(npol),dd(npol)
        real(kind=8) :: px(mmax),py(mmax),xx(mmax),yy(mmax),ang(mmax)
        real(kind=8) :: bd,bx,by,pxc,pyc,dmin,ddq,rr,th,ax,ay,di,jr,jt
        real(kind=8) :: xi,yi,gx,gy
        logical :: ok,dup

        ! 1) centres by "best candidate" sampling (blue noise)
        do i = 1,npol
            bd = -1.0d0; bx = 0.0d0; by = 0.0d0
            do c = 1,ncand
                pxc = dom * drand(rngix)
                pyc = dom * drand(rngix)
                dmin = huge( 1.0d0 )
                do j = 1,i-1
                    ddq = ( pxc-cx(j) )**2 + ( pyc-cy(j) )**2
                    if ( ddq .lt. dmin ) dmin = ddq
                end do
                if ( i .eq. 1 ) dmin = 0.0d0
                if ( dmin .gt. bd ) then
                    bd = dmin; bx = pxc; by = pyc
                end if
            end do
            cx(i) = bx; cy(i) = by
        end do

        ! 2) nearest neighbours (restricted Voronoi test) and cut-off radius
        kk = min( kviz, npol-1 )
        do i = 1,npol
            t = 0
            do j = 1,npol
                if ( j .eq. i ) cycle
                t = t + 1
                dd(t) = sqrt( ( cx(i)-cx(j) )**2 + ( cy(i)-cy(j) )**2 )
                idd(t) = j
            end do
            do a = 1,kk
                b = a
                do c = a+1,t
                    if ( dd(c) .lt. dd(b) ) b = c
                end do
                ddq = dd(a); dd(a) = dd(b); dd(b) = ddq
                ell = idd(a); idd(a) = idd(b); idd(b) = ell
            end do
            do a = 1,kk
                viz(a,i) = idd(a)
            end do
            nn(i)   = dd(1)
            rlim(i) = max( 0.6d0*dd(kk), dd(1) )
        end do

        nvmaxi = 0

        do i = 1,npol

            m = tam(i)

            ! 3) points uniform in the Voronoi cell of the centre, clipped
            !    to the domain; the final jitter lets a point cross the cell
            !    boundary, reproducing the slight overlap between
            !    neighbourhoods measured on the converted instances.
            mm = 0
            tent = 0
            maxtent = 400*m + 2000

            do while ( mm .lt. m .and. tent .lt. maxtent )

                tent = tent + 1

                rr = rlim(i) * sqrt( drand(rngix) )
                th = 2.0d0 * pi * drand(rngix)
                ax = cx(i) + rr * cos( th )
                ay = cy(i) + rr * sin( th )

                if ( ax .lt. 0.0d0 .or. ax .gt. dom .or. &
                     ay .lt. 0.0d0 .or. ay .gt. dom ) cycle

                di = ( ax-cx(i) )**2 + ( ay-cy(i) )**2
                ok = .true.
                do t = 1,kk
                    j = viz(t,i)
                    if ( ( ( ax-cx(j) )**2 + ( ay-cy(j) )**2 ) .lt. di ) then
                        ok = .false.
                        exit
                    end if
                end do
                if ( .not.ok ) cycle

                jr = jit * nn(i) * sqrt( drand(rngix) )
                jt = 2.0d0 * pi * drand(rngix)
                xi = dble( floor( ax + jr*cos(jt) + 0.5d0 ) )
                yi = dble( floor( ay + jr*sin(jt) + 0.5d0 ) )

                dup = .false.
                do t = 1,mm
                    if ( px(t) .eq. xi .and. py(t) .eq. yi ) then
                        dup = .true.
                        exit
                    end if
                end do
                if ( dup ) cycle

                mm = mm + 1
                px(mm) = xi
                py(mm) = yi

            end do

            ! safety net
            if ( mm .lt. 1 ) then
                mm = 1
                px(1) = dble( floor( cx(i) + 0.5d0 ) )
                py(1) = dble( floor( cy(i) + 0.5d0 ) )
            end if

            if ( mm .le. 2 ) then

                nvp(i) = mm
                do j = 1,mm
                    vcoor(1,j,i) = px(j)
                    vcoor(2,j,i) = py(j)
                end do

            else

                ! 4) counterclockwise angular sort around the centroid
                gx = sum( px(1:mm) ) / dble(mm)
                gy = sum( py(1:mm) ) / dble(mm)
                do j = 1,mm
                    ang(j) = atan2( py(j)-gy, px(j)-gx )
                end do
                call ordena_chave(mm,ang(1:mm),ordem(1:mm))
                do j = 1,mm
                    xx(j) = px(ordem(j))
                    yy(j) = py(ordem(j))
                end do

                ! 5) convex hull + reinsertion
                call fecho_convexo(mm,xx(1:mm),yy(1:mm),nh,hind(1:mm))

                if ( nh .le. 2 ) then
                    nvp(i) = 2
                    vcoor(1,1,i) = xx(hind(1))
                    vcoor(2,1,i) = yy(hind(1))
                    vcoor(1,2,i) = xx(hind(nh))
                    vcoor(2,2,i) = yy(hind(nh))
                else
                    call reinsere(mm,xx(1:mm),yy(1:mm),nh,hind(1:mm),kinsert)
                    nvp(i) = nh
                    do j = 1,nh
                        vcoor(1,j,i) = xx(hind(j))
                        vcoor(2,j,i) = yy(hind(j))
                    end do
                end if

            end if

            if ( nvp(i) .gt. nvmaxi ) nvmaxi = nvp(i)

        end do

        return

    end subroutine gera_instancia

end program generate_calibration
