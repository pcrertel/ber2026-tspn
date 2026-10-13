! =====================================================================
!  module geometry -> pt_seg plus geometric routines (GEOMPACK / Burkardt)
!
!  Pure geometric primitives: they know neither instance_type nor the
!  algorithm. The base of the dependency chain, using no other module.
! =====================================================================
module geometry

    implicit none

    contains

    pure function pt_seg(p,a,b) result(dist)

        implicit none
        
        real(kind=8), intent(in) :: p(2),a(2),b(2)

        ! Distance from point p to the segment [a,b]
    
        real(kind=8) :: dist,ab(2),ap(2),dd,tt
        ab = b - a
        ap = p - a
        dd = dot_product(ab,ab)
        if ( dd .le. 0.0d0 ) then
            dist = norm2(ap)
        else
            tt = max( 0.0d0, min( 1.0d0, dot_product(ap,ab) / dd ) )
            dist = norm2( ap - tt * ab )
        end if
    end function pt_seg

    subroutine polygon_centroid_2d ( n, v, centroid )

        !*****************************************************************************80
        !
        !! POLYGON_CENTROID_2D computes the centroid of a polygon in 2D.
        !
        !  Discussion:
        !
        !    Denoting the centroid coordinates by CENTROID, then
        !
        !      CENTROID(1) = Integral ( Polygon interior ) x dx dy / Area ( Polygon )
        !      CENTROID(2) = Integral ( Polygon interior ) y dx dy / Area ( Polygon ).
        !
        !    Green's theorem states that for continuously differentiable functions
        !    M(x,y) and N(x,y),
        !
        !      Integral ( Polygon boundary ) ( M dx + N dy ) =
        !      Integral ( Polygon interior ) ( dN/dx - dM/dy ) dx dy.
        !
        !    Using M(x,y) = 0 and N(x,y) = x*x/2, we get:
        !
        !      CENTROID(1) = 0.5 * Integral ( Polygon boundary ) x*x dy 
        !                  / Area ( Polygon ),
        !
        !    which becomes
        !
        !      CENTROID(1) = 1/6 sum ( 1 <= I <= N )
        !        ( X(I+1) + X(I) ) * ( X(I) * Y(I+1) - X(I+1) * Y(I))
        !        / Area ( Polygon )
        !
        !    where, when I = N, the index "I+1" is replaced by 1.
        !
        !    A similar calculation gives us a formula for CENTROID(2).
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    12 July 2003
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Reference:
        !
        !    Gerard Bashein, Paul Detmer,
        !    Centroid of a Polygon,
        !    in Graphics Gems IV, 
        !    edited by Paul Heckbert,
        !    AP Professional, 1994,
        !    T385.G6974.
        !
        !  Parameters:
        !
        !    Input, integer ( kind = 4 ) N, the number of sides of the polygon.
        !
        !    Input, real ( kind = 8 ) V(2,N), the coordinates of the vertices.
        !
        !    Output, real ( kind = 8 ) CENTROID(2), the coordinates of the centroid.
        !
        implicit none

        integer ( kind = 4 ) n
        integer ( kind = 4 ), parameter :: dim_num = 2

        real ( kind = 8 ) area
        real ( kind = 8 ) centroid(dim_num)
        integer ( kind = 4 ) i
        integer ( kind = 4 ) ip1
        real ( kind = 8 ) temp
        real ( kind = 8 ) v(dim_num,n)

        area = 0.0D+00
        centroid(1:dim_num) = 0.0D+00

        do i = 1, n

            if ( i < n ) then
                ip1 = i + 1
            else
                ip1 = 1
            end if

            temp = ( v(1,i) * v(2,ip1) - v(1,ip1) * v(2,i) )

            area = area + temp

            centroid(1:dim_num) = centroid(1:dim_num) &
            + ( v(1:dim_num,ip1) + v(1:dim_num,i) ) * temp

        end do

        area = area / 2.0D+00

        if ( area == 0.0D+00 ) then
            centroid(1:dim_num) = v(1:dim_num,1)
        else
            centroid(1:dim_num) = centroid(1:dim_num) / ( 6.0D+00 * area )
        end if

        return
    end subroutine polygon_centroid_2d

    subroutine segments_int_2d ( p1, p2, q1, q2, flag, r )

        !*****************************************************************************80
        !
        !! SEGMENTS_INT_2D computes the intersection of two line segments in 2D.
        !
        !  Discussion:
        !
        !    A line segment is the finite portion of a line that lies between
        !    two points P1 and P2.
        !
        !    In 2D, two line segments might not intersect, even though the
        !    lines, of which they are portions, intersect.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    05 January 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, real ( kind = 8 ) P1(2), P2(2), the endpoints of the first
        !    segment.
        !
        !    Input, real ( kind = 8 ) Q1(2), Q2(2), the endpoints of the second
        !    segment.
        !
        !    Output, integer ( kind = 4 ) FLAG, records the results.
        !    0, the line segments do not intersect.
        !    1, the line segments intersect.
        !
        !    Output, real ( kind = 8 ) R(2), an intersection point, if there is one.
        !
        implicit none

        integer ( kind = 4 ), parameter :: dim_num = 2

        integer ( kind = 4 ) flag
        integer ( kind = 4 ) ival
        real ( kind = 8 ) p1(dim_num)
        real ( kind = 8 ) p2(dim_num)
        real ( kind = 8 ) q1(dim_num)
        real ( kind = 8 ) q2(dim_num)
        real ( kind = 8 ) r(dim_num)
        real ( kind = 8 ), parameter :: tol = 0.001D+00
        real ( kind = 8 ) u(dim_num)

        !
        !  Find the intersection of the two lines.
        !
        r(1:dim_num) = (/ 0.0D+00, 0.0D+00 /)

        call lines_exp_int_2d ( p1, p2, q1, q2, ival, r )

        if ( ival == 0 ) then
            flag = 0
            return
        end if
        !
        !  Is the intersection point part of the first line segment?
        !
        call segment_contains_point_2d ( p1, p2, r, u )

        if ( u(1) < 0.0D+00 .or. 1.0D+00 < u(1) .or. tol < u(2) ) then
            flag = 0
            return
        end if
        !
        !  Is the intersection point part of the second line segment?
        !
        call segment_contains_point_2d ( q1, q2, r, u )

        if ( u(1) < 0.0D+00 .or. 1.0D+00 < u(1) .or. tol < u(2) ) then
            flag = 0
            return
        end if

        flag = 1

        return
    end subroutine
        
    subroutine lines_exp_int_2d ( p1, p2, q1, q2, ival, p )

        !*****************************************************************************80
        !
        !! LINES_EXP_INT_2D determines where two explicit lines intersect in 2D.
        !
        !  Discussion:
        !
        !    The explicit form of a line in 2D is:
        !
        !      the line through the points P1 and P2.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    02 January 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, real ( kind = 8 ) P1(2), P2(2), two points on the first line.
        !
        !    Input, real ( kind = 8 ) Q1(2), Q2(2), two points on the second line.
        !
        !    Output, integer ( kind = 4 ) IVAL, reports on the intersection:
        !    0, no intersection, the lines may be parallel or degenerate.
        !    1, one intersection point, returned in P.
        !    2, infinitely many intersections, the lines are identical.
        !
        !    Output, real ( kind = 8 ) P(2), if IVAl = 1, P is
        !    the intersection point.  Otherwise, P = 0.
        !
        implicit none

        integer ( kind = 4 ), parameter :: dim_num = 2

        real ( kind = 8 ) a1
        real ( kind = 8 ) a2
        real ( kind = 8 ) b1
        real ( kind = 8 ) b2
        real ( kind = 8 ) c1
        real ( kind = 8 ) c2
        integer ( kind = 4 ) ival
        logical ( kind = 4 ) point_1
        logical ( kind = 4 ) point_2
        real ( kind = 8 ) p(2)
        real ( kind = 8 ) p1(2)
        real ( kind = 8 ) p2(2)
        real ( kind = 8 ) q1(2)
        real ( kind = 8 ) q2(2)

        ival = 0
        p(1:dim_num) = 0.0D+00
        !
        !  Check whether either line is a point.
        !
        if ( all ( p1(1:dim_num) == p2(1:dim_num) ) ) then
            point_1 = .true.
        else
            point_1 = .false.
        end if

        if ( all ( q1(1:dim_num) == q2(1:dim_num) ) ) then
            point_2 = .true.
        else
            point_2 = .false.
        end if
        !
        !  Convert the lines to ABC format.
        !
        if ( .not. point_1 ) then
            call line_exp2imp_2d ( p1, p2, a1, b1, c1 )
        end if

        if ( .not. point_2 ) then
            call line_exp2imp_2d ( q1, q2, a2, b2, c2 )
        end if
        !
        !  Search for intersection of the lines.
        !
        if ( point_1 .and. point_2 ) then
            if ( all ( p1(1:dim_num) == q1(1:dim_num) ) ) then
                ival = 1
                p(1:dim_num) = p1(1:dim_num)
            end if
        else if ( point_1 ) then
            if ( a2 * p1(1) + b2 * p1(2) == c2 ) then
                ival = 1
                p(1:dim_num) = p1(1:dim_num)
            end if
        else if ( point_2 ) then
            if ( a1 * q1(1) + b1 * q1(2) == c1 ) then
                ival = 1
                p(1:dim_num) = q1(1:dim_num)
            end if
        else
            call lines_imp_int_2d ( a1, b1, c1, a2, b2, c2, ival, p )
        end if

        return
    end subroutine

    subroutine segment_contains_point_2d ( p1, p2, p, u )

        !*****************************************************************************80
        !
        !! SEGMENT_CONTAINS_POINT_2D reports if a line segment contains a point in 2D.
        !
        !  Discussion:
        !
        !    A line segment is the finite portion of a line that lies between
        !    two points P1 and P2.
        !
        !    In exact arithmetic, point P is on the line segment between
        !    P1 and P2 if and only if 0 <= U <= 1 and V = 0.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    17 August 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, real ( kind = 8 ) P1(2), P2(2), the endpoints of the line segment.
        !
        !    Input, real ( kind = 8 ) P(2), a point to be tested.
        !
        !    Output, real ( kind = 8 ) U(2), the components of P, with the first
        !    component measured along the axis with origin at P1 and unit at P2, 
        !    and second component the magnitude of the off-axis portion of the
        !    vector P-P1, measured in units of (P2-P1).
        !
        implicit none

        integer ( kind = 4 ), parameter :: dim_num = 2

        real ( kind = 8 ) normsq
        real ( kind = 8 ) p(dim_num)
        real ( kind = 8 ) p1(dim_num)
        real ( kind = 8 ) p2(dim_num)
        real ( kind = 8 ) u(dim_num)

        normsq = sum ( ( p2(1:dim_num) - p1(1:dim_num) )**2 )

        if ( normsq == 0.0D+00 ) then

            if ( all ( p(1:dim_num) == p1(1:dim_num) ) ) then
                u(1) = 0.5D+00
                u(2) = 0.0D+00
            else
                u(1) = 0.5D+00
                u(2) = huge ( u(2) )
            end if

        else

            u(1) = sum ( ( p(1:dim_num)  - p1(1:dim_num) ) &
                        * ( p2(1:dim_num) - p1(1:dim_num) ) ) / normsq

            u(2) = sqrt ( ( ( u(1) - 1.0D+00 ) * p1(1) - u(1) * p2(1) + p(1) )**2 &
                        + ( ( u(1) - 1.0D+00 ) * p1(2) - u(1) * p2(2) + p(2) )**2 ) &
                        / sqrt ( normsq )

        end if

        return
    end subroutine

    subroutine line_exp2imp_2d ( p1, p2, a, b, c )

        !*****************************************************************************80
        !
        !! LINE_EXP2IMP_2D converts an explicit line to implicit form in 2D.
        !
        !  Discussion:
        !
        !    The explicit form of a line in 2D is:
        !
        !      the line through the points P1 and P2.
        !
        !    The implicit form of a line in 2D is:
        !
        !      A * X + B * Y + C = 0
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    06 May 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, real ( kind = 8 ) P1(2), P2(2), two points on the line.
        !
        !    Output, real ( kind = 8 ) A, B, C, the implicit form of the line.
        !
        implicit none

        integer ( kind = 4 ), parameter :: dim_num = 2

        real ( kind = 8 ) a
        real ( kind = 8 ) b
        real ( kind = 8 ) c
        real ( kind = 8 ) norm
        real ( kind = 8 ) p1(dim_num)
        real ( kind = 8 ) p2(dim_num)
        !
        !  Take care of degenerate cases.
        !
        if ( line_exp_is_degenerate_nd ( dim_num, p1, p2 ) ) then
            write ( *, '(a)' ) ' '
            write ( *, '(a)' ) 'LINE_EXP2IMP_2D - Warning!'
            write ( *, '(a)' ) '  The line is degenerate.'
        end if

        a = p2(2) - p1(2)
        b = p1(1) - p2(1)
        c = p2(1) * p1(2) - p1(1) * p2(2)

        norm = a * a + b * b + c * c

        if ( 0.0D+00 < norm ) then
            a = a / norm
            b = b / norm
            c = c / norm
        end if

        if ( a < 0.0D+00 ) then
            a = -a
            b = -b
            c = -c
        end if

        return
    end subroutine

    subroutine lines_imp_int_2d ( a1, b1, c1, a2, b2, c2, ival, p )

        !*****************************************************************************80
        !
        !! LINES_IMP_INT_2D determines where two implicit lines intersect in 2D.
        !
        !  Discussion:
        !
        !    The implicit form of a line in 2D is:
        !
        !      A * X + B * Y + C = 0
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    25 February 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, real ( kind = 8 ) A1, B1, C1, define the first line.
        !    At least one of A1 and B1 must be nonzero.
        !
        !    Input, real ( kind = 8 ) A2, B2, C2, define the second line.
        !    At least one of A2 and B2 must be nonzero.
        !
        !    Output, integer ( kind = 4 ) IVAL, reports on the intersection.
        !
        !    -1, both A1 and B1 were zero.
        !    -2, both A2 and B2 were zero.
        !     0, no intersection, the lines are parallel.
        !     1, one intersection point, returned in P.
        !     2, infinitely many intersections, the lines are identical.
        !
        !    Output, real ( kind = 8 ) P(2), if IVAL = 1, then P is
        !    the intersection point.  Otherwise, P = 0.
        !
        implicit none

        integer ( kind = 4 ), parameter :: dim_num = 2

        real ( kind = 8 ) a(dim_num,dim_num+1)
        real ( kind = 8 ) a1
        real ( kind = 8 ) a2
        real ( kind = 8 ) b1
        real ( kind = 8 ) b2
        real ( kind = 8 ) c1
        real ( kind = 8 ) c2
        integer ( kind = 4 ) info
        integer ( kind = 4 ) ival
        real ( kind = 8 ) p(dim_num)

        p(1:dim_num) = 0.0D+00
        !
        !  Refuse to handle degenerate lines.
        !
        if ( line_imp_is_degenerate_2d ( a1, b1, c1 ) ) then
            ival = -1
            return
        end if

        if ( line_imp_is_degenerate_2d ( a2, b2, c2 ) ) then
            ival = -2
            return
        end if
        !
        !  Set up and solve a linear system.
        !
        a(1,1) = a1
        a(1,2) = b1
        a(1,3) = -c1

        a(2,1) = a2
        a(2,2) = b2
        a(2,3) = -c2

        call r8mat_solve ( 2, 1, a, info )
        !
        !  If the inverse exists, then the lines intersect at the solution point.
        !
        if ( info == 0 ) then

            ival = 1
            p(1:dim_num) = a(1:dim_num,3)
            !
            !  If the inverse does not exist, then the lines are parallel
            !  or coincident.  Check for parallelism by seeing if the
            !  C entries are in the same ratio as the A or B entries.
            !
        else

            ival = 0

            if ( a1 == 0.0D+00 ) then
                if ( b2 * c1 == c2 * b1 ) then
                    ival = 2
                end if
            else
                if ( a2 * c1 == c2 * a1 ) then
                    ival = 2
                end if
            end if

        end if

        return
    end subroutine

    subroutine r8mat_solve ( n, rhs_num, a, info )

        !*****************************************************************************80
        !
        !! R8MAT_SOLVE uses Gauss-Jordan elimination to solve an N by N linear system.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    29 August 2003
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, integer ( kind = 4 ) N, the order of the matrix.
        !
        !    Input, integer ( kind = 4 ) RHS_NUM, the number of right hand sides.  
        !    RHS_NUM must be at least 0.
        !
        !    Input/output, real ( kind = 8 ) A(N,N+rhs_num), contains in rows and
        !    columns 1 to N the coefficient matrix, and in columns N+1 through
        !    N+rhs_num, the right hand sides.  On output, the coefficient matrix
        !    area has been destroyed, while the right hand sides have
        !    been overwritten with the corresponding solutions.
        !
        !    Output, integer ( kind = 4 ) INFO, singularity flag.
        !    0, the matrix was not singular, the solutions were computed;
        !    J, factorization failed on step J, and the solutions could not
        !    be computed.
        !
        implicit none

        integer ( kind = 4 ) n
        integer ( kind = 4 ) rhs_num

        real ( kind = 8 ) a(n,n+rhs_num)
        real ( kind = 8 ) apivot
        real ( kind = 8 ) factor
        integer ( kind = 4 ) i
        integer ( kind = 4 ) info
        integer ( kind = 4 ) ipivot
        integer ( kind = 4 ) j

        info = 0

        do j = 1, n
            !
            !  Choose a pivot row.
            !
            ipivot = j
            apivot = a(j,j)

            do i = j+1, n
                if ( abs ( apivot ) < abs ( a(i,j) ) ) then
                    apivot = a(i,j)
                    ipivot = i
                end if
            end do

            if ( apivot == 0.0D+00 ) then
                info = j
                return
            end if
            !
            !  Interchange.
            !
            do i = 1, n + rhs_num
                call r8_swap ( a(ipivot,i), a(j,i) )
            end do
            !
            !  A(J,J) becomes 1.
            !
            a(j,j) = 1.0D+00
            a(j,j+1:n+rhs_num) = a(j,j+1:n+rhs_num) / apivot
            !
            !  A(I,J) becomes 0.
            !
            do i = 1, n

                if ( i /= j ) then

                    factor = a(i,j)
                    a(i,j) = 0.0D+00
                    a(i,j+1:n+rhs_num) = a(i,j+1:n+rhs_num) - factor * a(j,j+1:n+rhs_num)

                end if

            end do

        end do

        return
    end subroutine

    subroutine r8_swap ( x, y )

        !*****************************************************************************80
        !
        !! R8_SWAP switches two R8's.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    01 May 2000
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input/output, real ( kind = 8 ) X, Y.  On output, the values of X and
        !    Y have been interchanged.
        !
        implicit none

        real ( kind = 8 ) x
        real ( kind = 8 ) y
        real ( kind = 8 ) z

        z = x
        x = y
        y = z

        return
    end subroutine

    function line_imp_is_degenerate_2d ( a, b, c )

        !*****************************************************************************80
        !
        !! LINE_IMP_IS_DEGENERATE_2D finds if an implicit point is degenerate in 2D.
        !
        !  Discussion:
        !
        !    The implicit form of a line in 2D is:
        !
        !      A * X + B * Y + C = 0
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    06 May 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, real ( kind = 8 ) A, B, C, the implicit line parameters.
        !
        !    Output, logical ( kind = 4 ) LINE_IMP_IS_DEGENERATE_2D, is true if the
        !    line is degenerate.
        !
        implicit none

        integer ( kind = 4 ), parameter :: dim_num = 2

        real ( kind = 8 ) a
        real ( kind = 8 ) b
        real ( kind = 8 ) c
        logical ( kind = 4 ) line_imp_is_degenerate_2d

        line_imp_is_degenerate_2d = ( a * a + b * b == 0.0D+00 )

        return
    end function line_imp_is_degenerate_2d

    function line_exp_is_degenerate_nd ( dim_num, p1, p2 )

        !*****************************************************************************80
        !
        !! LINE_EXP_IS_DEGENERATE_ND finds if an explicit line is degenerate in ND.
        !
        !  Discussion:
        !
        !    The explicit form of a line in ND is:
        !
        !      the line through the points P1 and P2.
        !
        !    An explicit line is degenerate if the two defining points are equal.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    06 May 2005
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Parameters:
        !
        !    Input, integer ( kind = 4 ) DIM_NUM, the spatial dimension.
        !
        !    Input, real ( kind = 8 ) P1(DIM_NUM), P2(DIM_NUM), two points on the line.
        !
        !    Output, logical ( kind = 4 ) LINE_EXP_IS_DEGENERATE_ND, is TRUE if the line
        !    is degenerate.
        !
        implicit none

        integer ( kind = 4 ) dim_num

        logical ( kind = 4 ) line_exp_is_degenerate_nd
        real ( kind = 8 ) p1(dim_num)
        real ( kind = 8 ) p2(dim_num)

        line_exp_is_degenerate_nd = ( all ( p1(1:dim_num) == p2(1:dim_num) ) )

        return
    end function line_exp_is_degenerate_nd

    subroutine polygon_contains_point_2d ( n, v, p, inside )

        !*****************************************************************************80
        !
        !! polygon_contains_point_2d finds if a point is inside a polygon.
        !
        !  Discussion:
        !
        !    The polygon does not need to be convex.
        !
        !  Licensing:
        !
        !    This code is distributed under the GNU LGPL license. 
        !
        !  Modified:
        !
        !    05 September 2020
        !
        !  Author:
        !
        !    John Burkardt
        !
        !  Input:
        !
        !    integer ( kind = 4 ) N, the number of nodes or vertices in 
        !    the polygon.  N must be at least 3.
        !
        !    real ( kind = 8 ) V(2,N), the vertices of the polygon.
        !
        !    real ( kind = 8 ) P(2), the coordinates of the point to be tested.
        !
        !  Output:
        !
        !    logical ( kind = 4 ) INSIDE, is TRUE if the point is inside 
        !    the polygon.
        !
        implicit none

        integer ( kind = 4 ) n

        integer ( kind = 4 ) i
        logical ( kind = 4 ) inside
        real ( kind = 8 ) p(2)
        real ( kind = 8 ) px1
        real ( kind = 8 ) px2
        real ( kind = 8 ) py1
        real ( kind = 8 ) py2
        real ( kind = 8 ) v(2,n)
        real ( kind = 8 ) xints

        inside = .false.

        px1 = v(1,1)
        py1 = v(2,1)
        xints = p(1) - 1.0D+00

        do i = 1, n

            px2 = v(1,mod(i,n)+1)
            py2 = v(2,mod(i,n)+1)

            if ( min ( py1, py2 ) < p(2) ) then
                if ( p(2) <= max ( py1, py2 ) ) then
                    if ( p(1) <= max ( px1, px2 ) ) then
                        if ( py1 /= py2 ) then
                            xints = ( p(2) - py1 ) * ( px2 - px1 ) / ( py2 - py1 ) + px1
                        end if
                        if ( px1 == px2 .or. p(1) <= xints ) then
                            inside = .not. inside
                        end if
                    end if
                end if
            end if

            px1 = px2
            py1 = py2

        end do

        return
    end subroutine polygon_contains_point_2d

end module geometry
