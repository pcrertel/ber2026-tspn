program stage2_sort_by_angle

  ! Stage 2 of the GTSP -> TSPN conversion pipeline.
  !
  ! Reads a GTSP instance in the plain numeric format produced by stage 1
  ! (stage1_read_gtsp) and rewrites it with the points of every cluster
  ! sorted counterclockwise by the angle they make with the geometric centre
  ! of the cluster.  The angular order is what lets stage 3 (stage3_build_polygons) walk
  ! the interior points of a cluster cheaply while it carves the triangular
  ! slices out of the convex hull.
  !
  ! The input and output formats are the same:
  !
  !     npol  max(nvp)
  !     nvp(1)
  !     x y            (nvp(1) lines)
  !     ...
  !
  ! Usage:
  !     stage2_sort_by_angle <input.dat> <output-dir>
  !
  ! This code was adapted from the GVRPgen.f90 program, which generated
  ! random GVRP instances by drawing the points of each client into a ring
  ! around it and then sorting them counterclockwise by angle.  Here the
  ! points come from a GTSP instance instead of being drawn at random, and
  ! only the angular sorting was kept.

  implicit none

  ! PARAMETERS
  logical, parameter :: debug = .false.
  real(kind=8), parameter :: pi = acos( -1.0d0 )

  ! LOCAL SCALARS
  integer :: allocerr,i,j,k,nargs,nclients,npmax
  real(kind=8) :: x,y

  ! LOCAL ARRAYS
  integer, allocatable :: np(:)
  real(kind=8), allocatable :: ang(:),coord(:,:),p(:,:,:)
  character(len=512) :: filename,outdir,outfn

  nargs = command_argument_count()

  if ( nargs .lt. 1 .or. nargs .gt. 2 ) then
     write(*,*) 'Usage: stage2_sort_by_angle <input.dat> <output-dir>'
     stop 1
  end if

  call get_command_argument(1,filename)

  if ( nargs .eq. 2 ) then
     call get_command_argument(2,outdir)
  else
     outdir = '.'
  end if

  outfn = trim(adjustl(outdir))//'/'//trim(basename_noext(filename))//'.dat'

  open(unit=1010,file=trim(adjustl(filename)),status='old',err=300)

  read(1010,*,err=400,end=400) nclients,npmax

  allocate(coord(1:nclients,2),np(1:nclients),p(1:nclients,npmax,2),ang(npmax), &
           stat=allocerr)

  if ( allocerr .ne. 0 ) then
     write(*,*) 'Allocation error.'
     stop 1
  end if

  do i = 1,nclients
     read(1010,*,err=400,end=400) np(i)
     do j = 1,np(i)
        read(1010,*,err=400,end=400) p(i,j,1:2)
     end do
     coord(i,1) = (1.0d0/np(i))*sum(p(i,1:np(i),1))
     coord(i,2) = (1.0d0/np(i))*sum(p(i,1:np(i),2))
  end do

  close(1010)

  do i = 1,nclients
     if ( np(i) .gt. 2 ) then ! with two points or fewer there is nothing to sort
         do j = 1,np(i)
            ! Centre the point on the geometric centre of its cluster, so
            ! that the angle below is measured from that centre.
            x = p(i,j,1) - coord(i,1)
            y = p(i,j,2) - coord(i,2)
            if ( x .gt. 0.0d0 ) then
               ang(j) = atan(y/x)
            else if ( x .lt. 0.0d0 .and. y .ge. 0.0d0 ) then
               ang(j) = atan(y/x) + pi
            else if ( x .lt. 0.0d0 .and. y .lt. 0.0d0 ) then
               ang(j) = atan(y/x) - pi
            else if ( x .eq. 0.0d0 .and. y .gt. 0.0d0 ) then
               ang(j) = 0.5d0 * pi
            else if ( x .eq. 0.0d0 .and. y .lt. 0.0d0 ) then
               ang(j) = - 0.5d0 * pi
            else ! the point coincides with the centre: angle 0 by convention
               write(*,*) 'Point coincident with the centre of its cluster:'
               write(*,*) 'i = ',i,' j = ',j,' coord(i,1:2) = ',coord(i,1:2), &
                          ' p(i,j,1:2) = ',p(i,j,1:2)
               ang(j) = 0.0d0
            end if
            if ( ang(j) .lt. 0.0d0 ) then
               ang(j) = ang(j) + 2.0d0 * pi
            end if
         end do

         ! Sorting by angle
         do j = 1,np(i) - 1
            do k = j + 1,np(i)
               if ( ang(k) .lt. ang(j) ) then
                  call dswap(ang(k),ang(j))
                  call dswap(p(i,k,1),p(i,j,1))
                  call dswap(p(i,k,2),p(i,j,2))
               end if
            end do
         end do

         if ( debug ) write(*,*) 'angles: ',ang(1:np(i))
      end if
  end do

  if ( debug ) then
     do i = 1,nclients
        do j = 1,np(i)
           write(*,*) 'i: ',i,' j: ',j, p(i,j,1:2)
        end do
     end do
  end if

  open(unit=10,file=trim(outfn),err=500)

  write(10,*) nclients,npmax

  do i = 1,nclients
     write(10,*) np(i)
     do j = 1,np(i)
        write(10,*) p(i,j,1:2)
     end do
  end do

  close(10)

  deallocate(coord,np,p,ang,stat=allocerr)

  if ( allocerr .ne. 0 ) then
     write(*,*) 'Deallocation error.'
     stop 1
  end if

  stop

  ! Input file could not be opened
300 continue
  write(*,*) 'Could not open input file: ',trim(adjustl(filename))
  stop 1

  ! Error reading input file
400 continue
  write(*,*) 'Error reading input file: ',trim(adjustl(filename))
  stop 1

  ! Output file could not be opened
500 continue
  write(*,*) 'Could not open output file: ',trim(outfn)
  write(*,*) 'Does the output directory exist?'
  stop 1

contains

  subroutine dswap(a,b)

    implicit none

    ! SCALAR ARGUMENTS
    real(kind=8), intent(inout) :: a,b

    ! LOCAL SCALARS
    real(kind=8) :: temp

    temp = a
    a = b
    b = temp

  end subroutine dswap

  ! Strips the directory part and the extension of a path, so that
  ! "../inst/momlib/10att48.dat" becomes "10att48".

  function basename_noext(path) result(base)

    implicit none

    character(len=*), intent(in) :: path
    character(len=512) :: base

    integer :: ib,ie

    base = trim(adjustl(path))

    ib = index(base,'/',back=.true.) + 1

    ie = index(base,'.',back=.true.) - 1
    if ( ie .lt. ib ) then
       ie = len_trim(base)
    end if

    base = base(ib:ie)

  end function basename_noext

end program stage2_sort_by_angle
