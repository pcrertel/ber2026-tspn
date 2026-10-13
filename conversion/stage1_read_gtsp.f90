program stage1_read_gtsp

  ! Stage 1 of the GTSP -> TSPN conversion pipeline.
  !
  ! Reads a GTSP instance in the TSPLIB/GTSPLIB text format and writes it
  ! in the plain numeric format used by the remaining stages:
  !
  !     npol  max(nvp)
  !     nvp(1)
  !     x y            (nvp(1) lines)
  !     nvp(2)
  !     x y            (nvp(2) lines)
  !     ...
  !
  ! Usage:
  !     stage1_read_gtsp <input.gtsp> <output-dir>
  !
  ! The name of the output file is derived from the name of the INPUT FILE,
  ! not from the "NAME :" field of the instance.  Several instances of both
  ! libraries carry a "NAME :" field that disagrees with their own file name
  ! (see doc/known-issues.md), so the file name is the reliable identifier.
  !
  ! The reader tolerates the format variations found across the two source
  ! libraries, namely:
  !
  !   - "KEY : value", "KEY: value" and lower/mixed case keys;
  !   - DIMENSION and GTSP_SETS given in either order;
  !   - GTSP_SET_SECTION entries wrapped over several physical lines
  !     (the entry ends at the -1 terminator, wherever it falls);
  !   - trailing blanks on section headers and data lines.
  !
  ! Only instances that provide explicit node coordinates (NODE_COORD_SECTION)
  ! can be converted; the conversion is geometric and there is no way to
  ! recover coordinates from an EXPLICIT distance matrix.

  implicit none

  ! PARAMETERS
  logical, parameter :: debug = .false.
  integer, parameter :: nline = 10000
  integer, parameter :: iunit = 10

  ! LOCAL SCALARS
  integer :: allocerr,i,idum,j,k,npol,npoints,nargs

  ! LOCAL ARRAYS
  integer, allocatable :: nvp(:)
  real(kind=8), allocatable :: point(:,:),vcoor(:,:,:)
  character(len=512) :: filename,outdir,outputfn

  ! TOKENIZER STATE (used by nexttoken/refill below)
  character(len=nline) :: buf
  integer :: bpos,blen

  nargs = command_argument_count()

  if ( nargs .lt. 1 .or. nargs .gt. 2 ) then
     write(*,*) 'Usage: stage1_read_gtsp <input.gtsp> <output-dir>'
     stop 1
  end if

  call get_command_argument(1,filename)

  if ( nargs .eq. 2 ) then
     call get_command_argument(2,outdir)
  else
     outdir = '.'
  end if

  outputfn = trim(adjustl(outdir))//'/'//trim(basename_noext(filename))//'.dat'

  if ( debug ) then
     write(*,*) 'input  = ',trim(adjustl(filename))
     write(*,*) 'output = ',trim(outputfn)
  end if

  open(unit=iunit,file=trim(adjustl(filename)),status='old',err=300)

  ! --- Header: DIMENSION and GTSP_SETS, in whatever order they appear -----

  npoints = -1
  npol    = -1

  call scanheader(npoints,npol)

  if ( npoints .le. 0 ) then
     write(*,*) 'Could not find a valid DIMENSION field in ',trim(adjustl(filename))
     stop 1
  end if

  if ( npol .le. 0 ) then
     write(*,*) 'Could not find a valid GTSP_SETS field in ',trim(adjustl(filename))
     stop 1
  end if

  if ( debug ) then
     write(*,*) 'npoints = ',npoints
     write(*,*) 'npol    = ',npol
  end if

  allocate(point(2,npoints),nvp(npol),vcoor(2,npoints,npol),stat=allocerr)
  if ( allocerr .ne. 0 ) then
     write(*,*) 'Allocation error.'
     stop 1
  end if

  ! --- NODE_COORD_SECTION -------------------------------------------------

  call findsection('NODE_COORD_SECTION')

  do i = 1,npoints
     read(iunit,*,err=400,end=200) idum,point(1:2,i)
     if ( idum .ne. i ) then
        write(*,*) 'Node ',i,' is numbered ',idum,' in ',trim(adjustl(filename))
        stop 1
     end if
  end do

  ! --- GTSP_SET_SECTION ---------------------------------------------------

  call findsection('GTSP_SET_SECTION')

  bpos = 1
  blen = 0

  nvp(1:npol) = 0

  do i = 1,npol

     call nexttoken(k)

     if ( k .ne. i ) then
        write(*,*) 'Set ',i,' is numbered ',k,' in ',trim(adjustl(filename))
        stop 1
     end if

     do
        call nexttoken(k)

        if ( k .eq. -1 ) exit

        if ( k .lt. 1 .or. k .gt. npoints ) then
           write(*,*) 'Set ',i,' refers to node ',k,', out of 1..',npoints
           stop 1
        end if

        nvp(i) = nvp(i) + 1
        vcoor(1:2,nvp(i),i) = point(1:2,k)
     end do

     if ( debug ) then
        write(*,*) 'set ',i,' has ',nvp(i),' points'
     end if

  end do

  close(iunit)

  ! --- Output -------------------------------------------------------------

  open(unit=20,file=trim(outputfn),err=500)

  write(20,*) npol,maxval(nvp(1:npol))

  do i = 1,npol
     write(20,*) nvp(i)
     do j = 1,nvp(i)
        write(20,*) vcoor(1:2,j,i)
     end do
  end do

  close(20)

  go to 600

  ! Unexpected end of file
200 continue
  write(*,*) 'Unexpected end of file: ',trim(adjustl(filename))
  stop 1

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
  write(*,*) 'Could not open output file: ',trim(outputfn)
  write(*,*) 'Does the output directory exist?'
  stop 1

600 continue

contains

  ! Reads the whole file once looking for the DIMENSION and GTSP_SETS
  ! header fields, then rewinds.  Scanning the whole file makes the reader
  ! independent of the order of the two fields, which differs between
  ! instances (276nrw1379, for one, lists GTSP_SETS first).

  subroutine scanheader(np,ns)

    implicit none

    integer, intent(out) :: np,ns

    integer :: ios
    character(len=nline) :: ln

    np = -1
    ns = -1

    rewind(iunit)

    do
       read(iunit,fmt='(A)',iostat=ios) ln
       if ( ios .ne. 0 ) exit

       if ( keymatch(ln,'DIMENSION') ) then
          read(unit=ln(index(ln,':')+1:),fmt=*,iostat=ios) np
          if ( ios .ne. 0 ) np = -1
       else if ( keymatch(ln,'GTSP_SETS') ) then
          read(unit=ln(index(ln,':')+1:),fmt=*,iostat=ios) ns
          if ( ios .ne. 0 ) ns = -1
       end if

       if ( np .gt. 0 .and. ns .gt. 0 ) exit
    end do

    rewind(iunit)

  end subroutine scanheader

  ! Advances the input unit to just past the given section header.

  subroutine findsection(name)

    implicit none

    character(len=*), intent(in) :: name

    integer :: ios
    character(len=nline) :: ln

    rewind(iunit)

    do
       read(iunit,fmt='(A)',iostat=ios) ln
       if ( ios .ne. 0 ) then
          write(*,*) 'Section ',trim(name),' not found in ',trim(adjustl(filename))
          stop 1
       end if
       if ( trim(adjustl(ln)) .eq. name ) return
    end do

  end subroutine findsection

  ! Returns the next blank-separated integer of the current section,
  ! refilling the line buffer as needed.  Entries of GTSP_SET_SECTION are
  ! wrapped at about column 80 in part of the GTSP-Lib, so a set may span
  ! several physical lines; reading a token stream rather than a line at a
  ! time is what makes those instances readable.

  subroutine nexttoken(val)

    implicit none

    integer, intent(out) :: val

    integer :: ios,istart

    do
       ! Skip blanks, refilling the buffer at the end of each line.
       do while ( bpos .gt. blen )
          read(iunit,fmt='(A)',iostat=ios) buf
          if ( ios .ne. 0 ) then
             write(*,*) 'Unexpected end of file while reading ',trim(adjustl(filename))
             stop 1
          end if
          bpos = 1
          blen = len_trim(buf)
       end do

       if ( buf(bpos:bpos) .eq. ' ' .or. buf(bpos:bpos) .eq. achar(9) ) then
          bpos = bpos + 1
          cycle
       end if

       exit
    end do

    istart = bpos

    do while ( bpos .le. blen )
       if ( buf(bpos:bpos) .eq. ' ' .or. buf(bpos:bpos) .eq. achar(9) ) exit
       bpos = bpos + 1
    end do

    read(unit=buf(istart:bpos-1),fmt=*,iostat=ios) val

    if ( ios .ne. 0 ) then
       write(*,*) 'Could not read an integer from "',buf(istart:bpos-1),'" in ', &
                  trim(adjustl(filename))
       stop 1
    end if

  end subroutine nexttoken

  ! Strips the directory part and the extension of a path, so that
  ! "../inst/momlib/10att48.gtsp" becomes "10att48".

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

  ! Case-insensitive test for a TSPLIB header line of the form
  ! "<KEY> : <value>", tolerating the missing blank before the colon that a
  ! handful of instances of both libraries exhibit.

  function keymatch(ln,key) result(match)

    implicit none

    character(len=*), intent(in) :: ln,key
    logical :: match

    integer :: i,icolon
    character(len=64) :: lhs

    match = .false.

    icolon = index(ln,':')
    if ( icolon .le. 1 ) return

    lhs = adjustl(ln(1:icolon-1))
    if ( len_trim(lhs) .ne. len_trim(key) ) return

    do i = 1,len_trim(key)
       if ( upper(lhs(i:i)) .ne. upper(key(i:i)) ) return
    end do

    match = .true.

  end function keymatch

  function upper(c) result(u)

    implicit none

    character, intent(in) :: c
    character :: u

    if ( c .ge. 'a' .and. c .le. 'z' ) then
       u = achar( iachar(c) - 32 )
    else
       u = c
    end if

  end function upper

end program stage1_read_gtsp
