import ast
import os
import glob
import matplotlib.pyplot as plt
import matplotlib.patheffects as path_effects # needed for the text outline
import numpy as np 
from docplex.mp.model import Model
from docplex.mp.solution import SolveSolution
import gc
from multiprocessing import Process

# *******************************************************
# ****************** Reads input files ******************
# *******************************************************

def read_input_file(file_path):
    """
    Reads the input data available in the file 'file_path'.
    """
    data = {}
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Pre-processing
        content = content.replace('{', '[').replace('}', ']')
        comandos = content.split(';')
        
        for comando in comandos:
            comando = comando.strip()
            if not comando or '=' not in comando:
                continue
                
            leftside, var_value_str = comando.split('=', 1)
            
            # Get the last word before the equal sign (the variable name)
            tokens = leftside.split()
            if not tokens: continue
            var_name = tokens[-1]
            
            var_value_str = var_value_str.strip()
            
            try:
                value = ast.literal_eval(var_value_str)
                data[var_name] = value
            except Exception as e:
                print(f"  [Warning] Variable '{var_name}' ignored in the file {os.path.basename(file_path)}.")
                
        return data
        
    except Exception as e:
        print(f"Critical error while reading {file_path}: {e}")
        return None

# ********************************************************

def read_initial_sol(filename,m):
    """
    Reads an initial solution for the TSPN for the instance "filename" with m polygons.
    """
    # Defines the base name of the file containing the data to be read (ex: 'nn-sol-10berlin52.dat')
    base_name = f"nn-sol-{filename}"
    
    # Defines the directory where the file is located (ex: 'nn-solution')
    directory = "nn-solution"
    
    # Combine the directory and base name using the operating system separator
    full_path = os.path.join(directory, base_name)

    # Initialize the variables
    xymax = None
    tour = np.zeros(m, dtype=int)
    x = np.zeros((2, m), dtype=np.float64)
    tourlenght = None
    nntime = None

    # Open the file for reading
    with open(full_path, 'r') as fh:
        lines = fh.readlines()
    
    # Ensure that the number of lines is consistent with M (1 + 2*M + 2)
    expected_lines = 1 + (2 * m) + 2
    if len(lines) < expected_lines:
        print(f"Please note: The file only has {len(lines)} lines, but {expected_lines} are expected for m={m}.")
        return None, None, None, None, None
    
    # Read xymax
    try:
        # Take the first line, clear it, and try to convert it.
        xymax = float(lines[0].strip().split()[0])
    except (IndexError, ValueError) as e:
        print(f"Error reading xymax on the first line: {e}")
        return None, None, None, None, None
    
    # Read tour and x array (lines 2 : 2*M + 1)
    for i in range(m):
        # The line index is:
        # tour (polygon index): 1 + 2*i
        # x,y (coordinates): 1 + 2*i + 1
        
        # Tour reading
        try:
            line_idx = 1 + (2 * i) 
            tour_fields = lines[line_idx].strip().split()
            tour[i] = int(tour_fields[0])
        except (IndexError, ValueError) as e:
            print(f"Error reading tour[{i}] (polygon {i+1}) in line {line_idx + 1}: {e}. Stopping polygon processing.")
            break # Exit the loop if there is an error in the central data
            
        # --- Reading X and Y (the line of coordinates) ---
        try:
            coord_idx = line_idx + 1
            xy_values = [float(val) for val in lines[coord_idx].strip().split()]
            
            if len(xy_values) >= 2:
                # x[0, i] stores the x-coordinate
                x[0, i] = xy_values[0] 
                # x[1, i] stores the y-coordinate
                x[1, i] = xy_values[1]
            else:
                raise ValueError("Coordinate line with fewer than 2 values.")
                
        except (IndexError, ValueError) as e:
            print(f"Error reading x,y for the polygon {i+1} in line {coord_idx + 1}: {e}. Stopping polygon processing.")
            break
            
    # Read tourlenght
    try:
        tourlenght = float(lines[-2].strip().split()[0])
    except (IndexError, ValueError) as e:
        print(f"Warning: Error reading tour length (penultimate line). The value may be missing or incorrect.: {e}")
        
    # Read nntime
    try:
        nntime = float(lines[-1].strip().split()[0])
    except (IndexError, ValueError) as e:
        print(f"Warning: Error reading nntime (last line). The value may be missing or incorrect.: {e}")

    return xymax, tour, x, tourlenght, nntime

# ********************************************************

def read_all_instance_files(foldername, instfolder):
    """
    Initial processing to access the folder containing the instance files, 
    and then read each of these files with the instance data.
    """
    # Defines the path to the folder containing the instances for the CPLEX.
    target_folder = os.path.join(foldername, instfolder)
    search_pattern = os.path.join(target_folder, '*.dat')

    # Master dictionary to store all instances
    instance_set = {}

    print(f"Looking for files in: {search_pattern}")
    files_found = glob.glob(search_pattern)

    if not files_found:
        print("No .dat file found! Check the folder path.")
    else:
        files_sorted = sorted(files_found)

        print(f"Found {len(files_sorted)} files.")

        for file_path in files_sorted:
            # Take only the file name (e.g., “10eil76.dat”) to use as the key.
            filename = os.path.basename(file_path)
            
            print(f" -> Reading: {filename}")
            instdata_instancia = read_input_file(file_path)
            
            if instdata_instancia:
                instance_set[filename] = instdata_instancia

    print(f"Number of instances loaded: {len(instance_set)}")

    return instance_set

# *******************************************************
# ******** Calculate the barycenter of polygons *********
# *******************************************************

def polygon_barycenter(vertices):
    """
    Calculates the barycenter (Cx, Cy) of a polygon using the area formula (Shoelace).
    vertices: Array n x 2 [[x1, y1], [x2, y2], ...].
    """
    x = vertices[:, 0]
    y = vertices[:, 1]
    
    # Creates offset vectors to connect point i to i+1 (closing the cycle at the end)
    # np.roll(-1) makes the index element 0 go to the end
    x_next = np.roll(x, -1)
    y_next = np.roll(y, -1)
    
    # (xi * yi+1 - xi+1 * yi)
    cross_product = (x * y_next) - (x_next * y)
    signed_area = np.sum(cross_product) / 2.0
    
    # Protection against zero-area polygons (collinear or repeated points)
    if abs(signed_area) < 1e-9:
        return np.mean(vertices, axis=0)
        
    # Calculate Baricenter Coordinates (Cx, Cy)
    # Cx = (1/6A) * sum((xi + xi+1) * cross_product)
    # Cy = (1/6A) * sum((yi + yi+1) * cross_product)
    cx = np.sum((x + x_next) * cross_product) / (6.0 * signed_area)
    cy = np.sum((y + y_next) * cross_product) / (6.0 * signed_area)
    
    return np.array([cx, cy], dtype=np.float64)

# ********************************************************

def calculate_barycenters(C, xpg, ypg):
    """
    Calculates the barycenters of a list of polygons C with vertices [xpg, ypg].
    """
    xpg = np.array(xpg, dtype=np.float64)
    ypg = np.array(ypg, dtype=np.float64)
    
    barycenters = []
    
    for k, cluster_indices in enumerate(C):
        # Index adjustment -> 0-based
        idx_py = [i - 1 for i in cluster_indices]
        
        # Build a vertex array [[x, y], [x, y]...] for each polygon.
        # np.column_stack join arrays x and y side by side
        xcoords = xpg[idx_py]
        ycoords = ypg[idx_py]
        polvertices = np.column_stack((xcoords, ycoords))
        
        centroid = polygon_barycenter(polvertices)
        
        barycenters.append(centroid)

    return barycenters

# *******************************************************
# ***************** Auxiliary functions *****************
# *******************************************************

def point_in_convex_polygon(vpi, polygon, xp, yp, tol=1e-6):
    """
    Checks whether the point vpi belongs to the convex polygon whose vertices are
    given by the (1-based) indices in 'polygon'. The same half-plane test used
    when building the MIP start is applied here, so that a point accepted by this
    routine is also accepted there.
    """
    q_il = len(polygon)
    idx = [j - 1 for j in polygon]

    if q_il == 1:
        return bool(np.isclose(vpi[0], xp[idx[0]], atol=1e-8) and
                    np.isclose(vpi[1], yp[idx[0]], atol=1e-8))

    if q_il == 2:
        return belongs_to_segment(vpi, [xp[idx[0]], yp[idx[0]]], [xp[idx[1]], yp[idx[1]]])

    poly_x = xp[idx]
    poly_y = yp[idx]

    for k_py in range(q_il):
        x1, y1 = poly_x[k_py], poly_y[k_py]
        x2, y2 = poly_x[(k_py + 1) % q_il], poly_y[(k_py + 1) % q_il]

        a_const = y2 - y1
        b_const = x1 - x2
        c_const = x2 * y1 - x1 * y2

        maxcoef = max( 1.0, abs(a_const), abs(b_const), abs(c_const) )

        if ( a_const * vpi[0] + b_const * vpi[1] + c_const ) / maxcoef > tol:
            return False

    return True

# *******************************************************

def largest_subpolygon_barycenter(partition, xp, yp):
    """
    Returns the barycenter of the convex polygon of largest area among those in
    'partition', the convex partition of a neighborhood. Since the barycenter
    of a convex polygon always lies in its interior, the point returned is
    guaranteed to belong to the neighborhood.
    """
    best_area = -1.0
    best_point = None

    for polygon in partition:
        idx = [j - 1 for j in polygon]
        V = np.column_stack((xp[idx], yp[idx]))

        if len(idx) == 1:
            area, point = 0.0, V[0]
        elif len(idx) == 2:
            area, point = 0.0, V.mean(axis=0)
        else:
            xv, yv = V[:, 0], V[:, 1]
            area = abs( np.sum( xv * np.roll(yv, -1) - np.roll(xv, -1) * yv ) ) / 2.0
            point = polygon_barycenter(V)

        if area > best_area:
            best_area, best_point = area, point

    return np.array(best_point, dtype=np.float64)

# *******************************************************

def repair_initial_visit_points(x0, tour0, U, xp, yp):
    """
    Makes sure that every visit point of the initial solution belongs to its
    neighborhood. The barycenter of a non-convex polygon may fall outside it, in
    which case no convex polygon of the partition contains the point, the MIP
    start is incomplete and CPLEX rejects it. Whenever this happens the point is
    replaced by the barycenter of the convex polygon of largest area of that
    neighborhood.
    """
    nrepaired = 0

    for k in range(len(tour0)):
        i_py = tour0[k] - 1
        partition = U[i_py]
        vpi = (x0[0, k], x0[1, k])

        if any( point_in_convex_polygon(vpi, polygon, xp, yp) for polygon in partition ):
            continue

        x0[:, k] = largest_subpolygon_barycenter(partition, xp, yp)
        nrepaired += 1
        print(f"  [Initial solution] Visit point of neighborhood {i_py + 1} was outside it "
              f"and has been replaced by the barycenter of the largest convex polygon "
              f"of its partition.")

    return x0, nrepaired

# *******************************************************

def belongs_to_segment(p, v1, v2):
    """
    Check if point p(2) is on segment [v1(2), v2(2)] (including the endpoints).
    """
    p = np.array(p, dtype=np.float64)
    v1 = np.array(v1, dtype=np.float64)
    v2 = np.array(v2, dtype=np.float64)
    
    # Collinearity test
    pv1 = p - v1
    v2v1 = v2 - v1
    
    # Vector product
    cross_product = pv1[0] * v2v1[1] - pv1[1] * v2v1[0]
    
    # If the vector product is close to zero, they are collinear.
    if not np.isclose(cross_product, 0.0, atol=1e-9):
        return False # They are not collinear

    # Check if p is between v1 and v2 (and not on the extended line)
    x_min = min(v1[0], v2[0])
    x_max = max(v1[0], v2[0])
    y_min = min(v1[1], v2[1])
    y_max = max(v1[1], v2[1])
    
    # We check if p[0] is between [x_min, x_max] and p[1] between [y_min, y_max].
    # We added tolerance to cover the extremes due to float errors.
    is_px_bounded = (p[0] >= x_min - 1e-9) and (p[0] <= x_max + 1e-9)
    is_py_bounded = (p[1] >= y_min - 1e-9) and (p[1] <= y_max + 1e-9)
    
    return is_px_bounded and is_py_bounded

# ********************************************************

def calculate_inequality_constraint(pi_x, pi_y, pol_x, pol_y):
    """
    Check whether the point (pi_x, pi_y) satisfies the inequality on all sides of the polygon.
    """
    q_il = len(pol_x)
    max_inequality_value = -float('inf')
    
    # Loop over all sides of the polygon
    for k_py in range(q_il):
        # Points V_k and V_{k+1}
        x1 = pol_x[k_py]
        y1 = pol_y[k_py]
        x2 = pol_x[(k_py + 1) % q_il] 
        y2 = pol_y[(k_py + 1) % q_il] 
        
        # Calculate Coefficients a, b and c
        a = y2 - y1
        b = x1 - x2
        c = x2 * y1 - x1 * y2
        
        maxcoef = max( 1.0, abs(a), abs(b), abs(c) )

        a = a / maxcoef
        b = b / maxcoef
        c = c / maxcoef
        
        # Test the Inequality: a*pi_x + b*pi_y + c
        # If the polygon was chosen (w_il=1), the Big M constraint requires ineq <= 0.
        ineqvalue = a * pi_x + b * pi_y + c
        
        # Updates the maximum inequality value found 
        if ineqvalue > max_inequality_value:
            max_inequality_value = ineqvalue
            
    return max_inequality_value

# ********************************************************

def distance_point_segment(pi_x, pi_y, v1_coords, v2_coords):
    """
    Calculate the minimum distance between point (pi_x, pi_y) and segment v1v2.
    """
    v1 = np.array(v1_coords, dtype=np.float64)
    v2 = np.array(v2_coords, dtype=np.float64)
    pi = np.array([pi_x, pi_y], dtype=np.float64)
    
    v1v2 = v2 - v1          # Segment vector
    v1pi = pi - v1           # Vector from origin v1 to point pi
    
    # Segment Length Square
    L_sq = np.dot(v1v2, v1v2)
    
    # v1 and v2 are the same point (Segmento degenerado)
    if L_sq < 1e-6:
        # Distance between pi and v1
        return np.hypot(v1pi[0], v1pi[1])
        
    # Calculate Projection (Parameter ‘t’ or Lambda)
    t = np.dot(v1pi, v1v2) / L_sq
    
    if t < 0.0:
        # Projection falls before v1. The closest point is v1.
        mindist = np.hypot(v1pi[0], v1pi[1]) 
    elif t > 1.0:
        # Projection falls after v2. The closest point is v2.
        v2pi = pi - v2 
        mindist = np.hypot(v2pi[0], v2pi[1]) # distance from pi to v2
    else:
        # The closest point q is on the segment.
        q = v1 + t * v1v2
        piq = pi - q
        mindist = np.hypot(piq[0], piq[1])

    return mindist

# ********************************************************

def check_feasibility_solution(m, U, xp, yp, solution, w, px, py):
    """
    Checks which polygon (point, segment, polygon) the optimal point belongs to and 
    checks the feasibility of the constraints.
    """
    if not solution:
        print("Error: No solution was found.")
        return

    npol = range(1, m + 1)
    max_violation_vector = []
    
    # Extract Optimized Variables
    px_sol = {i: solution.get_value(px[i]) for i in npol}
    py_sol = {i: solution.get_value(py[i]) for i in npol}
    
    for i_model in npol:
        # Visiting point (px, py)
        pi_x = px_sol.get(i_model, 0)
        pi_y = py_sol.get(i_model, 0)
        
        l_star = None
        q_il = 0
        
        group_u = U[i_model - 1]
        
        for ell_py, polygon in enumerate(group_u):
            ell_model = ell_py + 1
            
            # Checks whether w_il has been created and whether it is 1 in the solution.
            if (i_model, ell_model) in w:
                w_sol = solution.get_value(w[i_model, ell_model])
                if w_sol > 0.9:
                    l_star = ell_model
                    q_il = len(polygon)
                    break
        
        cluster_max_violat = 0.0 # default for the non-polygonal cases

        if l_star is None:
            print(" ERROR: No w_il=1 choice found for this cluster .")
            cluster_max_violat = float('inf')
            continue
        
        if q_il == 1:
            # Isolated point
            polygon_indices = group_u[l_star - 1]
            v_idx_0_based = polygon_indices[0] - 1 
            
            vx = xp[v_idx_0_based]
            vy = yp[v_idx_0_based]
            
            dx_abs = abs(pi_x - vx)
            dy_abs = abs(pi_y - vy)
            
            stress_distance = max(dx_abs, dy_abs) 
            
            cluster_max_violat = stress_distance
        
        elif q_il == 2:
            # Segment
            polygon_indices = group_u[l_star - 1]
            
            v1_idx_0_based = polygon_indices[0] - 1 
            v2_idx_0_based = polygon_indices[1] - 1 
            
            v1 = [xp[v1_idx_0_based], yp[v1_idx_0_based]]
            v2 = [xp[v2_idx_0_based], yp[v2_idx_0_based]]
            
            # Shortest distance from pi to segment v1v2
            cluster_max_violat = distance_point_segment(pi_x, pi_y, v1, v2)
            
        elif q_il >= 3:
            # Polygon
            polygon_indices = group_u[l_star - 1]
            v_indices_0_based = [idx - 1 for idx in polygon_indices]
            poly_x = xp[v_indices_0_based]
            poly_y = yp[v_indices_0_based]

            # Calculate the largest value of the inequality
            cluster_max_violat = calculate_inequality_constraint(pi_x, pi_y, poly_x, poly_y)

        # Stores the highest measure of feasibility for each neighborhood
        max_violation_vector.append((q_il, cluster_max_violat))
        
    return max_violation_vector

# *******************************************************
# *********** Functions for plotting solutions **********
# *******************************************************

def plot_initial_tour(m, C, xpg, ypg, xsol, cost, xymax, filename):
    """
    Plot an initial tour solution for the TSPN.
    """
    # --- LaTeX-like style ---
    # Computer Modern as the mathematical font, as in LaTeX
    plt.rcParams['mathtext.fontset'] = 'cm'

    filename = os.path.basename(filename).replace('.dat', '')
    base_name = f"ini-sol-{filename}.pdf"
    directory = "plot-solutions"
    full_path_figure = os.path.join(directory, base_name)

    # Create the directory if it does not exist
    os.makedirs(directory, exist_ok=True)

    xmax = np.max( np.abs( xpg ) )
    ymax = np.max( np.abs( ypg ) )
    xyamax = max( 1.0, xmax, ymax )

    xpgcopy = np.array(xpg, dtype=np.float64) / xyamax
    ypgcopy = np.array(ypg, dtype=np.float64) / xyamax
    barycenters = calculate_barycenters(C, xpgcopy, ypgcopy)

    xsolcopy = xsol / xyamax

    fig, ax = plt.subplots(figsize=(10, 8))
    cmap = plt.get_cmap("tab10") 

    for k, cluster_indices in enumerate(C):
        idx_py = [i - 1 for i in cluster_indices]
        pts_x = xpgcopy[idx_py]
        pts_y = ypgcopy[idx_py]
        
        # Close the polygon
        plot_x = np.append(pts_x, pts_x[0])
        plot_y = np.append(pts_y, pts_y[0])
        
        cor = cmap(k % 10)
        
        # Plot the polygons
        ax.fill(plot_x, plot_y, color=cor, alpha=0.3)
        ax.plot(plot_x, plot_y, color=cor, linewidth=1)
        
        cx, cy = barycenters[k]
        # ax.text(cx, cy, f" {k+1}", fontsize=8, fontweight='bold', color='black')
        label_latex = f"$\\mathbf{{{k+1}}}$"
        # label_latex = r"$\mathbf{" + str(k+1) + r"}$"
        text_obj = ax.text(cx, cy, label_latex, 
                           fontsize=12, # a little larger, to compensate for the thin font
                           color='black', 
                           ha='left', va='bottom',
                           zorder=10) # Fica no topo da pilha de desenho
        
        # A white outline around the text, for contrast
        # text_obj.set_path_effects([path_effects.withStroke(linewidth=1.5, foreground='white')])

    # Plot the route solution
    plotxxsol = np.append(xsolcopy[0,:], xsolcopy[0,0])
    plotyxsol = np.append(xsolcopy[1,:], xsolcopy[1,0])
    ax.plot(plotxxsol, plotyxsol, color='red', linewidth=1.5, alpha=0.9, zorder=2)

    for k in range(m):
        ax.plot(xsolcopy[0,k], xsolcopy[1,k], 'ro', markersize=3, zorder=3)
    
    # --- Styling Alterado ---
    
    # Equal aspect ratio, so that the geometry is not distorted
    ax.set_aspect('equal') 
    
    # Remove eixos, labels, bordas e grid
    ax.axis('off')
    
    # bbox_inches='tight' drops the excess white border, and pad_inches=0
    # drops the extra padding, leaving only the figure
    print(f"Saving file: {full_path_figure}")
    plt.savefig(full_path_figure, format='pdf', bbox_inches='tight', pad_inches=0)
    plt.close(fig)
    print(f"TSPN initial solution figure saved in: {full_path_figure}")

# ********************************************************

def plot_model_solution(C, xpg, ypg, xymax, solution, x, px, py, filename):
    """
    Plot the model solution for the TSPN with labels at barycenters.
    """
    if solution is None:
        print("Error: No solution for plotting.")
        return

    # --- LaTeX-like style ---
    # Computer Modern as the mathematical font, as in LaTeX
    plt.rcParams['mathtext.fontset'] = 'cm'

    filename = os.path.basename(filename).replace('.dat', '')
    base_name = f"model-sol-{filename}.pdf"
    directory = "plot-solutions"
    full_path_figure = os.path.join(directory, base_name)
    
    # Make sure the directory exists
    os.makedirs(directory, exist_ok=True)

    xmax = np.max( np.abs( xpg ) )
    ymax = np.max( np.abs( ypg ) )
    xyamax = max( 1.0, xmax, ymax )

    fig, ax = plt.subplots(figsize=(10, 8))
    xpgcopy = np.array(xpg, dtype=np.float64) / xyamax
    ypgcopy = np.array(ypg, dtype=np.float64) / xyamax
    barycenters = calculate_barycenters(C, xpgcopy, ypgcopy)
    cmap = plt.get_cmap("tab10")

    # Dictionary for storing optimal points: {ID_Polygon: (px, py)}
    optimal_points = {}
    
    for k, cluster_indices in enumerate(C):
        # 0-based indices
        idx_py = [i - 1 for i in cluster_indices]
        pts_x = xpgcopy[idx_py]
        pts_y = ypgcopy[idx_py]
        plot_x = np.append(pts_x, pts_x[0])
        plot_y = np.append(pts_y, pts_y[0])
        
        cor = cmap(k % 10)
        
        # Draw Polygon (Area + Boundary)
        ax.fill(plot_x, plot_y, color=cor, alpha=0.3, zorder=0)
        ax.plot(plot_x, plot_y, color=cor, linewidth=1, zorder=0)
        
        # --- The number is placed at the barycenter ---
        # The barycenter here is the plain mean of the vertex coordinates
        cx, cy = barycenters[k]
        label_latex = f"$\\mathbf{{{k+1}}}$"
        # ax.text(cx, cy, label_latex, fontsize=12, color='black', ha='center', va='center', zorder=10)
        # label_latex = r"$\mathbf{" + str(k+1) + r"}$"
        
        text_obj = ax.text(cx, cy, label_latex, 
                           fontsize=12, # a little larger, to compensate for the thin font
                           color='black', 
                           ha='left', va='bottom', 
                           zorder=10) # Fica no topo da pilha de desenho
        
        # A white outline around the text, for contrast
        # text_obj.set_path_effects([path_effects.withStroke(linewidth=1.5, foreground='white')])

        # Extract visiting point (px_i, py_i) for polygon (i=k+1)
        i_model = k + 1
        if i_model in px:
            x_sol = solution.get_value(px[i_model]) / xyamax
            y_sol = solution.get_value(py[i_model]) / xyamax
            optimal_points[i_model] = (x_sol, y_sol)
            
            # --- Only the red point is drawn, with no text ---
            ax.plot(x_sol, y_sol, 'ro', markersize=3, zorder=3)

    # Plot tour    
    tour_arcos = []
    
    for (i, j), var in x.items():
        if solution.get_value(var) > 0.9: # Arco ativo
            tour_arcos.append((i, j))
            
    for i, j in tour_arcos:
        # Coordinates of the exit point (i) and arrival point (j)
        pi_x, pi_y = optimal_points[i]
        pj_x, pj_y = optimal_points[j]
        
        ax.plot([pi_x, pj_x], [pi_y, pj_y], 'r-', 
                linewidth=1.5, 
                alpha=0.9, 
                zorder=2)
        
    ax.set_aspect('equal') 
    ax.axis('off') # Remove eixos, bordas e grade
    
    print(f"Saving file: {full_path_figure}")
    plt.savefig(full_path_figure, format='pdf', bbox_inches='tight', pad_inches=0)
    plt.close(fig)
    print(f"TSPN model solution figure saved in: {full_path_figure}")

# ********************************************************

def draw_solution_metapost(m, C, xpg, ypg, xsol, instname, output_dir):
    """
    Reproduces the Fortran drawsol subroutine to generate a MetaPost (.mp) file.
    """
    xmax = np.max( np.abs( xpg ) )
    ymax = np.max( np.abs( ypg ) )
    xyamax = max( 1.0, xmax, ymax )

    instfln = instname
    base_name = os.path.basename(instfln).replace('.dat', '')
    plotfn = os.path.join(output_dir, f'plot-model-{base_name}.mp')
    
    # Ensure that the directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Fortran uses ‘f20.17’ to format floats. We will use a similar format:
    FMT = lambda val: f"{val:20.17f}"
    
    # Open and write prologue
    with open(plotfn, 'w') as f:
        f.write("prologues := 3;\n")
        f.write("outputtemplate := \"%j.mps\";\n")
        f.write("beginfig(1);\n")
        f.write("u = 8.0cm;\n")
        f.write("color lavanda;  lavanda = (235/255,200/255,231/255);\n")
        
        # Fill the polygons
        for i_py in range(m): # i_py = 0 : m-1
            cluster_indices = C[i_py]
            
            f.write("fill\n") 
            
            # Loops over the vertices
            for j_py in range(len(cluster_indices)): 
                v_idx_1_based = cluster_indices[j_py]
                v_idx_0_based = v_idx_1_based - 1 # Python 0-based
                
                # Vertices
                f.write(f"( {FMT( xpg[v_idx_0_based] / xyamax )}*u,{FMT( ypg[v_idx_0_based] / xyamax )}*u)--\n")
                
            # Close and Color
            f.write("cycle withcolor lavanda;\n")
        
        # Draw the polygons
        for i_py in range(m):
            cluster_indices = C[i_py]
            
            f.write("draw\n") 
            
            # Loops over the vertices
            for j_py in range(len(cluster_indices)):
                v_idx_1_based = cluster_indices[j_py]
                v_idx_0_based = v_idx_1_based - 1 
                
                # Vertices
                f.write(f"( {FMT( xpg[v_idx_0_based] / xyamax )}*u,{FMT( ypg[v_idx_0_based] / xyamax )}*u)--\n")
                
            # Close and Set Style
            f.write("cycle withpen pencircle scaled 1.0pt withcolor black;\n")

        # Draw the path-solution
        f.write("draw\n")
        
        # xsol is 2 x m: xsol[0, i] = x, xsol[1, i] = y
        for i in range(m): # Go through all the points in the order of the tour
            f.write(f"( {FMT( xsol[0, i] / xyamax )}*u,{FMT( xsol[1, i] / xyamax )}*u)--\n")
            
        # Closes the Tour
        f.write(f"( {FMT( xsol[0, 0] / xyamax )}*u,{FMT( xsol[1, 0] / xyamax )}*u) withpen pencircle scaled 0.75pt withcolor red;\n")

        # Draw the points-solution
        for i in range(m):
            x_val = xsol[0, i]
            y_val = xsol[1, i]
            cor = 'red'
            f.write(f"fill fullcircle scaled 1.5pt shifted ({FMT( x_val / xyamax )}*u,{FMT( y_val / xyamax )}*u) withcolor {cor};\n")
            
        # Close the file
        f.write("endfig;\nend;\n")
        
    print(f"MetaPost file successfully generated in: {plotfn}")

# ********************************************************

def build_xsol_array(m: int, solution: SolveSolution, x: dict, px: dict, py: dict):
    """
    Build the xsol array (2 x m) with the coordinates of the visiting points [px,py] in the order of the solution tour found.
    """
    npol = range(1, m + 1)

    if not solution:
        return np.zeros((2, m)) 
        
    # Extract visiting points (Map: ID_Pol -> (X, Y))
    optimized_coords = {}
    for i in npol:
        if i in px:
            x_val = solution.get_value(px[i])
            y_val = solution.get_value(py[i])
            optimized_coords[i] = (x_val, y_val)
        # If a px/py has not been created, we use (0, 0) to avoid KeyErrors.
        else:
            optimized_coords[i] = (0.0, 0.0)

    # Extract Active Arcs and Map the Tour
    tour_map = {} 
    for (i, j), var in x.items():
        if solution.get_value(var) > 0.9:
            tour_map[i] = j 

    if not tour_map:
        return np.zeros((2, m))

    # Trace the Sequence and Set Up the Array
    xsol = np.zeros((2, m))
    
    start_node = list(tour_map.keys())[0]
    current_node = start_node
    k = 0 # Column index (Position in sequence)
    
    while k < m:
        # Assign coordinates of the current node to column k
        cx, cy = optimized_coords[current_node]
        xsol[0, k] = cx 
        xsol[1, k] = cy 
        
        next_node = tour_map.get(current_node)
        
        # Stop criterion: We have reached the end or the tour has closed
        if next_node is None or next_node == start_node:
            break
            
        current_node = next_node
        k += 1
        
    return xsol

# *******************************************************
# ************* Functions to generate tables ************
# *******************************************************

def table_instance_features(outputfile: str, instname: str, m, ng, n, h, nbivar, nrevar, nlic, nquac):
    """
    Must generate the latex table with the instance features.
    """
    base_name = os.path.basename(instname).replace('.dat', '')
    summi = sum(h)
    outline = ""
    
    # 1. instance name & m & |V| & \sum_{i=1}^m m_i & \sum_{i=1}^m \sum_{\ell=1}^{m_i} q_{i\ell} & #bi variables & #real variables & #linear const. & #quadratic const.
    outline += f"{base_name:16}   &   {m:5}   &   {ng:6}   &   {summi:6}   &   {n:8}   &   {nbivar:9}   &   {nrevar:9}   &   {nlic:9}   &   {nquac:9} \\\\\n"
        
    # Append the row to the file
    with open(outputfile, 'a') as f:
        f.write(outline)
        
    print(f"Instance features for {base_name} exported to {outputfile}.")

# ********************************************************

def table_model_solution(outputfile: str, instname: str, mdl: Model, solution: SolveSolution, xymax):
    """
    Must generate a table line with the description of the solutions found and effort measurements of the IBM ILOG CPLEX
    """
    base_name = os.path.basename(instname).replace('.dat', '')
    
    solve_details = mdl.get_solve_details()
    details = mdl.solve_details
    status = mdl.get_solve_status()
    status_str = str(status).replace("JobSolveStatus.", "")

    outline = ""
    outline += f"{base_name:16}   &   "
    
    if solution:
        # if status_str == "OPTIMAL_SOLUTION":
        #     outline += f"{xymax * solution.get_objective_value():17.4f}   &   "
        # elif status_str == "FEASIBLE_SOLUTION":
        # lb = xymax * details.best_bound
        # ub = xymax * solution.get_objective_value()
        # gap = details.mip_relative_gap
        # outline += f"[{lb:17.4f}, {ub:17.4f}] {gap:.2%}   &   "
        # else:
        #     print(f"There was a solution but it's not optimal nor feasible. Status = {status_str}.")
        #     return
        lb = xymax * details.best_bound
        ub = xymax * solution.get_objective_value()
        gap = details.mip_relative_gap
        outline += f"[{lb:17.5f}, {ub:17.5f}] {gap:.2%}   &   "
        
        # Number of iterations
        outline += f"{details.nb_iterations:18}   &   "

        # Number of B&B nodes
        outline += f"{details.nb_nodes_processed:18}   &   "

        # Time
        outline += f"{solve_details.time:7.2f}   &   {status_str}   \\\\\n"
    else:
        outline += "-----   &   "

        # Number of iterations
        outline += f"{details.nb_iterations:18}   &   "

        # Number of B&B nodes
        outline += f"{details.nb_nodes_processed:18}   &   "

        # Time
        outline += f"{solve_details.time:7.2f}   &   {status_str}   \\\\\n"
        
    # Append the row to the file
    with open(outputfile, 'a') as f:
        f.write(outline)
        
    print(f"Description solutions for {base_name} exported to {outputfile}.")

# ********************************************************

def print_tour_xsol(outputfile: str, instname: str, mdl, solution, x: dict, w, px: dict, py: dict, m, U, xp, yp, xymax):
    """
    Stores the tour and visiting points of the solution calculated by cplex.
    """
    base_name = os.path.basename(instname).replace('.dat', '')
    
    if not solution:
        # Records that the instance failed
        status = mdl.get_solve_status()
        status_str = str(status).replace("JobSolveStatus.", "")
        with open(outputfile, 'a') as f:
            f.write("\n" + "=" * 50 + "\n")
            f.write(f"Instance: {base_name} (FAILURE - NO SOLUTION). Status: {status_str}\n")
            f.write("=" * 50 + "\n\n")
        return
    
    macheps = np.spacing( np.float64( 1.0 ) )
    max_feas_violation_vector = check_feasibility_solution(m, U, xp, yp, solution, w, px, py)

    # Extract Active Arcs and Build the Tour Map (Origin -> Destination)
    tour_map = {}
    for (i, j), var in x.items():
        if solution.get_value(var) > 0.9:
            tour_map[i] = j 

    lentour = len(tour_map)
    if lentour == 0:
        print("WARNING: No active arcs (x_ij=1) found.")
        return 

    # Track the Tour in Sequence
    start_node = list(tour_map.keys())[0] # Arbitrary starting point (the first one we find)
    current_node = start_node
    tour_sequence = []
    
    while True:
        # Get the visit coordinates of the current point 
        x_coord = solution.get_value(px[current_node])
        y_coord = solution.get_value(py[current_node])
        
        # Store the point in the sequence
        tour_sequence.append({
            'node': current_node,
            'x': x_coord*xymax,
            'y': y_coord*xymax,
            'qil': max_feas_violation_vector[current_node-1][0],
            'viability': max_feas_violation_vector[current_node-1][1]
        })
        
        # Find the next node and move forward
        next_node = tour_map.get(current_node)
        
        if next_node is None or current_node == next_node:
            # If the tour does not close or there is a subtour of a node
            break
            
        current_node = next_node
        
        # Stop when you return to the beginning 
        if current_node == start_node:
            break

    # Writing to the Output File 
    with open(outputfile, 'a') as f:
        f.write("\n" + "=" * 60 + "\n")
        f.write(f"| Instance: {base_name:16} | CPLEX objective value - original: {xymax * solution.get_objective_value()}\n")
        f.write(f"| Instance: {base_name:16} | CPLEX objective value - scaled: {solution.get_objective_value()}\n")
        f.write("=" * 60 + "\n")
        f.write("Polygon |   Coord X (px) |   Coord Y (py) | Dist x->x_next |       Acum. dist  |   q_il | Is feasible?|   Feasibility measure \n")

        totaldist = 0.0
        maxfeasm = -float('inf')
    
        # Write the tour sequence 
        for k, step in enumerate(tour_sequence):

            knext = (k + 1) % len(tour_sequence)

            p1 = np.array([step['x'], step['y']], dtype=np.float64)

            next_step = tour_sequence[knext]

            p2 = np.array([next_step['x'], next_step['y']], dtype=np.float64)

            distp1p2 = np.linalg.norm( p1 - p2)
            totaldist += distp1p2

            maxfeasm = max( maxfeasm, step['viability'] )

            if step['viability'] >= macheps:
                feasible = 'INFEASIBLE'
            else:
                feasible = 'FEASIBLE'
            
            # The visitation order k is 1-based.
            f.write(f"{step['node']:7} | {step['x']:14.5f} | {step['y']:14.5f} | {distp1p2:14.5f} | {totaldist:17.5f} | {step['qil']:6} | {feasible:11} | {step['viability']}\n")

        f.write(f"Total tour length: {totaldist}\n")
        f.write(f"Max feasibility measure: {maxfeasm}\n")

    directory = "write-solutions"
    full_path = os.path.join(directory, f'sol-model-{base_name}.txt')

    with open(full_path, 'w') as f:
    
        for k, step in enumerate(tour_sequence):

            if step['viability'] >= macheps:
                feasible = 'INFEASIBLE'
            else:
                feasible = 'FEASIBLE'
            
            f.write(f"{step['node']:7}   {step['x']}   {step['y']}   {feasible:11}   {step['viability']}\n")

# *******************************************************
# ********* Creates and defines the MIQCP model *********
# *******************************************************

def create_tspn_model(m, h, xp, yp, U, tour0, timelimit, normalize, addconstraints):
    """
    Building the TSPN model to solve with CPLEX 
    """

    mdl = Model('TSPN_model')
    mdl.set_time_limit(timelimit)
    mdl.parameters.mip.limits.treememory = 112640
    mdl.parameters.workmem = 90000
    mdl.parameters.mip.strategy.file = 3

    # =========================================================================
    # Parameters - m, mi = h[i], q_il, v_il, a_il, b_il, c_il, bigM
    # =========================================================================

    # Set of indices npol = {1, 2, ..., m}
    npol = range(1, m + 1)

    if normalize:
        # bigM values when coordinates are scaled by xymax
        bigM1 = 2.0 * np.sqrt(2.0)
        bigM2 = 2.0
        bigM3 = 3.0
    else:
         # bigM values when coordinates are NOT scaled by xymax
        xmax = np.max( xp )
        xmin = np.min( xp )
        ymax = np.max( yp )
        ymin = np.min( yp )

        rcomp = xmax - xmin
        rlar = ymax - ymin

        bigM1 = np.hypot(rcomp, rlar)
        bigM2 = max( abs(rcomp), abs(rlar) )
        bigM3 = 3.0 * max( abs(xmax), abs(xmin), abs(ymax), abs(ymin) )        

    # =========================================================================
    # Decision variables - x, u, xi, gamma, lambda, w, px, py
    # =========================================================================

    # x_{ij} ∈ {0, 1} | i, j = 1,...,m, i ≠ j
    x = {
        (i, j): mdl.binary_var(name=f'x_{i}_{j}')
        for i in npol for j in npol if i != j 
    }
    
    # u_i ∈ [1, m-1] | i = 1,...,m (MTZ variable)
    u = mdl.continuous_var_dict(npol, lb = 1, ub = m, name = 'u')

    mdl.add_constraint(u[1] == 1, ctname="fix_u1")

    for i in range(2, m+1):
        mdl.add_constraint(u[i] >= 2)
        mdl.add_constraint(u[i] <= m)

    # xi_{ij} ∈ R | i, j = 1,...,m, i ≠ j
    xi = {
        (i, j): mdl.continuous_var(name=f'xi_{i}_{j}', lb=0 )
        for i in npol for j in npol if i != j 
    }

    if addconstraints:
        # xi^x_{ij} ∈ R | i, j = 1,...,m, i ≠ j
        xix = {
            (i, j): mdl.continuous_var(name=f'xix_{i}_{j}', lb=0 )
            for i in npol for j in npol if i != j 
        }

        # xi^y_{ij} ∈ R | i, j = 1,...,m, i ≠ j
        xiy = {
            (i, j): mdl.continuous_var(name=f'xiy_{i}_{j}', lb=0 )
            for i in npol for j in npol if i != j 
        }

    # gamma_{ij} ∈ R | i, j = 1,...,m, i ≠ j
    gamma = {
        (i, j): mdl.continuous_var(name=f'gamma_{i}_{j}', lb=0 )
        for i in npol for j in npol if i != j 
    }

    # lambda_{i\ell} ∈ R | i = 1,...,m, \ell = 1,...,m_i = h[i-1], if q_{i\ell} = 2
    lambdavar = {
        (i_py + 1, l_py + 1): mdl.continuous_var(name=f'lambda_{i_py + 1}_{l_py + 1}', lb=0, ub=1 )
        for i_py, partition in enumerate(U)
        for l_py, polygon in enumerate(partition)
        if len(polygon) == 2
    }
    
    # w_{i\ell} ∈ {0, 1} | i = 1,...,m, e \ell = 1,...,m_i = h[i-1]
    w = {
        (i, ell): mdl.binary_var(name=f'w_{i}_{ell}')
        for i in npol for ell in range(1, h[i-1] + 1)
    }

    xlo, xhi = float(np.min(xp)), float(np.max(xp))
    ylo, yhi = float(np.min(yp)), float(np.max(yp))

    # px ∈ R | i = 1,...,m 
    px = mdl.continuous_var_dict(npol, lb = xlo, ub = xhi, name = 'px')

    # py ∈ R | i = 1,...,m 
    py = mdl.continuous_var_dict(npol, lb = ylo, ub = yhi, name = 'py')
    
    # Checking variables 
    nbivar = len(x) + len(w)
    nrevar = len(u) + len(xi) + len(gamma) + len(lambdavar) + len(px) + len(py)

    if addconstraints:
        nrevar = nrevar + len(xix) + len(xiy)
        
    print(f"Number of binary variables: {nbivar}") 
    print(f"Number of continuous variables: {nrevar}") 
    print(f"Total number of variables: {mdl.number_of_variables}")
    
    # =========================================================================
    # Objective function
    # =========================================================================
    
    # Suppose that gamma contains only the variables where i ≠ j.
    mdl.minimize(mdl.sum(gamma.values()))

    # =========================================================================
    # Constraints
    # =========================================================================
    
    # For each i in npol, the sum of the outgoing arcs (x_ij) must be equal to 1.
    mdl.add_constraints(
        ( mdl.sum(x[i, j] for j in npol if i != j) == 1, f'x_leave_{i}' )
        for i in npol
    )

    # For each j in npol, the sum of the incoming arcs (x_ij) must be equal to 1.
    mdl.add_constraints(
        ( mdl.sum(x[i, j] for i in npol if i != j) == 1, f'x_enter_{j}' )
        for j in npol
    )

    # MTZ constraints: u_i - u_j + (m-1) * x_ij <= (m-2)
    mmtz = range(2, m + 1)  # mmtz = {2, ..., m}

    mdl.add_constraints(
        ( u[i] - u[j] + (m - 1) * x[i, j] <= (m - 2), f'mtz_u_{i}_{j}' )
        for i in mmtz for j in mmtz if i != j
    )

    # Euclidean distance constraints - Quadratic Constraint
    for i in npol:
        for j in npol:
            if i != j:
                quadratic_constraint = (
                    xi[i, j]**2 >= (px[i] - px[j])**2 + (py[i] - py[j])**2
                )
                
                mdl.add_constraint(
                    quadratic_constraint,
                    ctname=f'dist_quad_xi_{i}_{j}'
                )

    # If x_ij = 0, then gamma_ij <= 0 (so, gamma_ij = 0, since gamma_ij >= 0)
    mdl.add_constraints(
        ( gamma[i, j] <= bigM1 * x[i, j], f'bigM11_gamma_{i}_{j}' )
        for i in npol for j in npol if i != j
    )

    # If x_ij = 1, then gamma_ij >= xi_ij
    mdl.add_constraints(
        ( gamma[i, j] >= xi[i, j] - bigM1 * (1 - x[i, j]), f'bigM12_gamma_{i}_{j}' )
        for i in npol for j in npol if i != j
    )

    if addconstraints:
        # Aditional constraints to stregthen the model
        mdl.add_constraints(
            ( - xix[i, j] <= px[i] - px[j], f'add_const1_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

        mdl.add_constraints(
            ( px[i] - px[j] <= xix[i, j], f'add_const12_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

        mdl.add_constraints(
            ( - xiy[i, j] <= py[i] - py[j], f'add_const2_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

        mdl.add_constraints(
            ( py[i] - py[j] <= xiy[i, j], f'add_const22_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

        mdl.add_constraints(
            ( xi[i, j] >= xix[i, j], f'add_const3_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

        mdl.add_constraints(
            ( xi[i, j] >= xiy[i, j], f'add_const4_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

        mdl.add_constraints(
            ( xi[i, j] <= xix[i, j] + xiy[i, j], f'add_const5_{i}_{j}' )
            for i in npol for j in npol if i != j
        )

    # Constraints that guarantee the visiting points to belongs a polygon
    for i_py, partition in enumerate(U):    # i_py: 0-based index
        i_model = i_py + 1                      # model index i = (1-based) {1,...,m}
        # print(f"i_model: {i_model}") 
        # print(f"partition: {partition}") 

        for ell_py, polygon in enumerate(partition):   # ell_py: 0-based index
            ell_model = ell_py + 1                          # model index \ell = {1, 2, ..., h_i}
            # print(f"ell_model: {ell_model}") 
            # print(f"polygon: {polygon}") 
            
            q_il = len(polygon)                # Number of vertices q_i\ell

            if q_il == 1:     

                v_idx_1_based = polygon[0]
                v_idx_0_based = v_idx_1_based - 1 
                        
                # Constraint 1: px_i >= xp_il1 - M * (1 - w_il) e px_i <= xp_il1 + M * (1 - w_il)
                mdl.add_constraint(
                    px[i_model] >= xp[v_idx_0_based] - bigM2 * (1 - w[i_model, ell_model]), ctname=f'Px_q_{i_model}_{ell_model}_1_maior'
                )

                mdl.add_constraint(
                    px[i_model] <= xp[v_idx_0_based] + bigM2 * (1 - w[i_model, ell_model]), ctname=f'Px_q_{i_model}_{ell_model}_1_menor'
                )
                
                # Constraint 2: py_i >= yp_il1 - M * (1 - w_il) e py_i <= xy_il1 + M * (1 - w_il)
                mdl.add_constraint(
                    py[i_model] >= yp[v_idx_0_based] - bigM2 * (1 - w[i_model, ell_model]), ctname=f'Py_q_{i_model}_{ell_model}_1_maior'
                )

                mdl.add_constraint(
                    py[i_model] <= yp[v_idx_0_based] + bigM2 * (1 - w[i_model, ell_model]), ctname=f'Py_q_{i_model}_{ell_model}_1_menor'
                )
            elif q_il == 2:

                v1_idx = polygon[0] - 1 
                v2_idx = polygon[1] - 1 
                
                XP1 = xp[v1_idx]
                YP1 = yp[v1_idx]
                XP2 = xp[v2_idx]
                YP2 = yp[v2_idx]
                
                # Constraint 1
                mdl.add_constraint(
                    px[i_model] >= XP1 + lambdavar[i_model,ell_model] * (XP2 - XP1) - bigM2 * (1 - w[i_model,ell_model]), f'Px_q_{i_model}_{ell_model}_2_maior'
                )

                mdl.add_constraint(
                    px[i_model] <= XP1 + lambdavar[i_model,ell_model] * (XP2 - XP1) + bigM2 * (1 - w[i_model,ell_model]), f'Px_q_{i_model}_{ell_model}_2_menor'
                )
                
                # Constraint 2
                mdl.add_constraint(
                    py[i_model] >= YP1 + lambdavar[i_model,ell_model] * (YP2 - YP1) - bigM2 * (1 - w[i_model,ell_model]), f'Py_q_{i_model}_{ell_model}_2_maior'
                )

                mdl.add_constraint(
                    py[i_model] <= YP1 + lambdavar[i_model,ell_model] * (YP2 - YP1) + bigM2 * (1 - w[i_model,ell_model]), f'Py_q_{i_model}_{ell_model}_2_menor'
                )
            else: # q_il >= 3:

                v_indices_0_based = [idx - 1 for idx in polygon]
                
                poly_x = xp[v_indices_0_based]
                poly_y = yp[v_indices_0_based]
                
                # Loop over the polygon edges
                for k_py in range(q_il):
                    k_model = k_py + 1 # index k of the side (1-based)
                    
                    x1 = poly_x[k_py]
                    y1 = poly_y[k_py]
                    x2 = poly_x[(k_py + 1) % q_il]
                    y2 = poly_y[(k_py + 1) % q_il]
                    
                    # Equation of the line: a*x + b*y + c = 0
                    # a: y2 - y1
                    # b: x1 - x2
                    # c: x2 * y1 - x1 * y2
                    a_const = y2 - y1
                    b_const = x1 - x2
                    c_const = x2 * y1 - x1 * y2

                    maxcoef = max( 1.0, abs(a_const), abs(b_const), abs(c_const) )

                    a_const = a_const / maxcoef
                    b_const = b_const / maxcoef
                    c_const = c_const / maxcoef
                    
                    # 3. THE BIG-M CONSTRAINT
                    
                    # LADO ESQUERDO (lefts): a*px_i + b*py_i + c
                    lefts = (a_const * px[i_model] + b_const * py[i_model] + c_const)
                    
                    # LADO DIREITO (rights): M * (1 - w_il)
                    rights = bigM3 * (1 - w[i_model, ell_model])
                    
                    # Constraint: lefts <= rights
                    mdl.add_constraint( lefts <= rights, f'q_{q_il}_Poly_In_{i_model}_{ell_model}_Side_{k_model}' )
                
    # Constraint: The sum of the w_i\ell for a fixed group i must be 1.
    mdl.add_constraints(
        (mdl.sum(w[i, ell] for ell in range(1, h[i-1] + 1)) == 1, f'w_sum1_{i}') 
        for i in npol
    )

    # Checking the number of constraints
    nlic = mdl.number_of_linear_constraints
    nquac = mdl.number_of_quadratic_constraints

    print(f"Number of linear constraints: {nlic}") 
    print(f"Number of quadratic constraints: {nquac}") 
    print(f"Total number of model constraints: {mdl.number_of_constraints}")

    if addconstraints:
        return mdl, x, u, xi, xix, xiy, gamma, w, lambdavar, px, py, nbivar, nrevar, nlic, nquac
    else:
        return mdl, x, u, xi, gamma, w, lambdavar, px, py, nbivar, nrevar, nlic, nquac

# ********************************************************

# def add_mip_start(m, xp, yp, U, tour0, x0, mdl, x, u, xi, gamma, px, py, w, lambdavar):
def add_mip_start(m, xp, yp, U, tour0, x0, mdl, x, u, xi, gamma, px, py, w, lambdavar, xix=None, xiy=None):
    """
    Creates and adds to the model an initial solution, i.e., a MIP Start.
    """
    mip_start = SolveSolution(mdl)
    
    # Temporary map to store the visiting point by Polygon ID.
    cluster_coords_map = {}

    # Set u_i, px_i, py_i        
    for k in range(m):
        i_cluster = tour0[k]      # the cluster visited, and the index of px/py/u
        tour_position = k + 1      # its position along the tour, for u_i
        
        # Coordinates of the visit point at POSITION K
        px_coord = x0[0, k]
        py_coord = x0[1, k]
        cluster_coords_map[i_cluster] = (px_coord, py_coord)
        
        # set u_i
        if i_cluster in u:
            mip_start.add_var_value(u[i_cluster], tour_position)
        
        # Set px_i, py_i 
        if i_cluster in px: 
            mip_start.add_var_value(px[i_cluster], px_coord)
            mip_start.add_var_value(py[i_cluster], py_coord)
            
    # Set x_ij
    for k in range(m):
        i_origem = tour0[k]
        j_destino = tour0[(k + 1) % m] 

        if (i_origem, j_destino) in x:
            mip_start.add_var_value(x[i_origem, j_destino], 1)
            
    # Set xi_ij, gamma_ij
    for i_cluster in range(1, m + 1):
        for j_cluster in range(1, m + 1):
            if i_cluster != j_cluster:
                
                # 1. Take the coordinates from the map, to be sure of using the right point
                coord_i = cluster_coords_map.get(i_cluster)
                coord_j = cluster_coords_map.get(j_cluster)
                
                if coord_i is None or coord_j is None:
                    # A cluster that was not mapped, which cannot happen if tour0 is complete
                    continue
                
                # 2. The Euclidean distance (xi_ij)
                dist = np.hypot(coord_i[0] - coord_j[0], coord_i[1] - coord_j[1])
                
                # 3. set xi_ij = distance
                if (i_cluster, j_cluster) in xi:
                    mip_start.add_var_value(xi[i_cluster, j_cluster], dist)
                
                # 4. set gamma_ij wheter exists
                if (i_cluster, j_cluster) in gamma:
                    arc_active = 0
                    for k in range(m):
                        if tour0[k] == i_cluster and tour0[(k+1)%m] == j_cluster:
                            arc_active = 1
                            break
                            
                    if arc_active:
                        mip_start.add_var_value(gamma[i_cluster, j_cluster], dist)
                    else:
                        mip_start.add_var_value(gamma[i_cluster, j_cluster], 0)
                
                # 5. set xix_ij, xiy_ij (somente quando addconstraints=True)
                if xix is not None and (i_cluster, j_cluster) in xix:
                    mip_start.add_var_value(xix[i_cluster, j_cluster], abs(coord_i[0] - coord_j[0]))
                if xiy is not None and (i_cluster, j_cluster) in xiy:
                    mip_start.add_var_value(xiy[i_cluster, j_cluster], abs(coord_i[1] - coord_j[1]))
    
    # Set w_i\ell, lambdavar_i\ell
    for i_py, partition in enumerate(U):    # i_py: 0-based index
        i_model = i_py + 1                      # model index i = (1-based) {1,...,m}

        vpi = cluster_coords_map.get(i_model)

        wisset = False

        for ell_py, polygon in enumerate(partition):   # ell_py: 0-based index
            ell_model = ell_py + 1                          # model index \ell = {1, 2, ..., h_i}
            
            if not wisset:

                q_il = len(polygon)                # Number of vertices q_i\ell

                if q_il == 1:     
                    
                    vert = np.array([xp[polygon[0] - 1], yp[polygon[0] - 1]], dtype=np.float64)

                    diff = np.isclose(vpi, vert, atol=1e-8)

                    # Set w_i\ell
                    if diff.all(): # diff = [True, True]
                        mip_start.add_var_value(w[i_model, ell_model], 1)
                        wisset = True
                    else:
                        mip_start.add_var_value(w[i_model, ell_model], 0)

                elif q_il == 2:
                    
                    v1_idx = polygon[0] - 1 
                    v2_idx = polygon[1] - 1 

                    V1 = [xp[v1_idx], yp[v1_idx]]
                    V2 = [xp[v2_idx], yp[v2_idx]]

                    if belongs_to_segment(vpi, V1, V2):
                        
                        # 3. If the point lies on the segment, compute lambda, its projection
                        dx = V2[0] - V1[0]
                        dy = V2[1] - V1[1]
                        L_sq = dx**2 + dy**2
                        
                        # Avoids a division by zero when V1 == V2
                        if L_sq > 1e-9:
                            # The projection formula that gives lambda
                            lambda_val = ((vpi[0] - V1[0]) * dx + (vpi[1] - V1[1]) * dy) / L_sq
                            
                            # Limita lambda a [0, 1] devido a arredondamentos
                            lambda_val = max(0.0, min(1.0, lambda_val))
                        else:
                            lambda_val = 0.0 # when the neighborhood is a single point
                            
                        # Set w_i\ell and lambdavar_i\ell; lambda_vars[i_model, ell_model] has to exist for the case q_il = 2
                        if (i_model, ell_model) in lambdavar:
                            mip_start.add_var_value(lambdavar[i_model, ell_model], lambda_val)

                            # Makes w_i\ell equal to 1 when this is the selected segment
                            mip_start.add_var_value(w[i_model, ell_model], 1)

                            wisset = True
                    else:
                        mip_start.add_var_value(w[i_model, ell_model], 0)

                else: # q_il >= 3:
                    inpol = True
                    v_indices_0_based = [idx - 1 for idx in polygon]
                    
                    poly_x = xp[v_indices_0_based]
                    poly_y = yp[v_indices_0_based]
                    
                    # Loop over polygon edges
                    for k_py in range(q_il):
                        # Pontos V_k e V_{k+1}
                        x1 = poly_x[k_py]
                        y1 = poly_y[k_py]
                        x2 = poly_x[(k_py + 1) % q_il]  # Fecha o ciclo
                        y2 = poly_y[(k_py + 1) % q_il]
                        
                        a_const = y2 - y1
                        b_const = x1 - x2
                        c_const = x2 * y1 - x1 * y2

                        maxcoef = max( 1.0, abs(a_const), abs(b_const), abs(c_const) )

                        a_const = a_const / maxcoef
                        b_const = b_const / maxcoef
                        c_const = c_const / maxcoef
                        
                        # Inequality: a*px + b*py + c <= 0
                        inequality_value = a_const * vpi[0] + b_const * vpi[1] + c_const

                        # If the inequality is violated, value > 0 up to the tolerance, the point is outside
                        if inequality_value > 1e-6:
                            inpol = False # the point is outside the polygon
                            break

                    # Set w_i\ell
                    if inpol:
                        mip_start.add_var_value(w[i_model, ell_model], 1)
                        wisset = True
                    else:
                        mip_start.add_var_value(w[i_model, ell_model], 0)
            else:
                mip_start.add_var_value(w[i_model, ell_model], 0)

    # Adds an complete initial solution to the model
    mdl.add_mip_start(mip_start)
    print("MIP Start (Initial Solution) successfully added to the model.")

    return mip_start
    
# ********************************************************

def fix_tour(mdl, m, tour0, x):
    """
    Used to optimize only the visiting points.
    """              
    # Creates a set of tuples (source, destination) for active arcs
    tour_arcos_ativos = set()
    for k in range(m):
        i_origem = tour0[k]
        j_destino = tour0[(k + 1) % m]
        tour_arcos_ativos.add((i_origem, j_destino))
    
    npol = range(1, m + 1)
    for i in npol:
        for j in npol:
            if i != j:

                arc = (i, j) 
                
                if arc in x: # only if the variable x[i, j] was created in the model
                    
                    var_x = x[i, j]
                    
                    if arc in tour_arcos_ativos:
                        # Caso 1: Arco ATIVO - FIXAR x_ij = 1
                        fixing_value = 1
                    else:
                        # Caso 2: Arco INATIVO - FIXAR x_ij = 0
                        fixing_value = 0
                        
                    mdl.add_constraint( var_x == fixing_value, ctname=f'fix_x_{i}_{j}' )

    print(f"Total of {len(tour_arcos_ativos)} fixed arcs as 1.")
    return x
 
# ********************************************************

def solve_single_instance(instname, instdata, timelimit, solve_only_vispoints, normalize, addconstraints):
    """
    Solve one instance of TSPN using CPLEX.
    This function will be executed in a SEPARATE PROCESS,
    which guarantees that all memory (CPLEX internal memory included)
    will be fully released when the process ends.
    """
    
    print(f"\n>>> Solving instance {instname} in a separate process...")
    
    # Number of clients (neighborhoods)
    m = int(instdata['m'])
    ng = int(instdata['ng'])
    C = instdata['C']
    xpg = np.array(instdata['xpg'], dtype=np.float64)
    ypg = np.array(instdata['ypg'], dtype=np.float64)
    # TSPN data - non-convex neighborhoods partitioned into convex polygons
    n = int(instdata['n'])
    h = instdata['h']
    U = instdata['U']
    xp = np.array(instdata['xp'], dtype=np.float64)
    yp = np.array(instdata['yp'], dtype=np.float64)

    # print(f"Number of neighborhoods (clients) m: {m}")   
    # print(f"Number of GTSP cluster points ng: {ng}")    
    # print(f"GTSP cluster points C: {C}")
    # print(f"Coordenadas XPG: {xpg}")
    # print(f"Coordenadas YPG: {ypg}")
    # print(f"Total number of neighborhood vertices n: {n}")
    # print(f"Number of polygons in each neighborhood h: {h}")
    # print(f"Vertices of each polygon in each neighborhood U: {U}")
    # print(f"Coordenadas XP: {xp}")
    # print(f"Coordenadas YP: {yp}")

    # =========================================================================
    # Building an initial route with NN and normalizing the vertices
    # =========================================================================

    xymax, tour0, x0, nn_cost, nntime = read_initial_sol(f"{instname}", m)
    print(f"Initial tour: {tour0}")
    print(f"Initial cost - original: { nn_cost * xymax }")
    print(f"Initial cost - scale: { nn_cost }")

    if normalize:
        # Normalizing the vertices coordinates
        xpg[:] = xpg / xymax
        ypg[:] = ypg / xymax
        xp[:] = xp / xymax
        yp[:] = yp / xymax
    else:
        for k in range(m):
            x0[:,k] = xymax * x0[:,k]
            # print(f"x0 {k}: {x0[:,k]}")

        nn_cost = nn_cost * xymax
        xymax = 1.0

    # =========================================================================
    # Set the model
    # =========================================================================

    if addconstraints:
        mdl, x, u, xi, xix, xiy, gamma, w, lambdavar, px, py, nbivar, nrevar, nlic, nquac = create_tspn_model(m, h, xp, yp, U, tour0, timelimit, normalize, addconstraints)
    else:
        mdl, x, u, xi, gamma, w, lambdavar, px, py, nbivar, nrevar, nlic, nquac = create_tspn_model(m, h, xp, yp, U, tour0, timelimit, normalize, addconstraints)

    if solve_only_vispoints:

        barycenters = calculate_barycenters(C, xpg, ypg)
        x0 = np.zeros((2, m))
        for k in range(m):
            x0[:,k] = barycenters[tour0[k]-1]
        
        deltas = np.diff(x0, axis=1)
        distances = np.linalg.norm(deltas, axis=0)
        soma_total = np.sum(distances)
        return_dist = np.linalg.norm(x0[:, -1] - x0[:, 0])
        soma_ciclo_completo = soma_total + return_dist
        nn_cost = soma_ciclo_completo * xymax
        print(f"Initial solution cost: {nn_cost}")

        x = fix_tour(mdl, m, tour0, x)

    # Every visit point of the initial solution must belong to its neighborhood,
    # otherwise the MIP start is incomplete and is rejected by CPLEX.
    x0, nrepaired = repair_initial_visit_points(x0, tour0, U, xp, yp)

    if nrepaired > 0:
        deltas = np.diff(x0, axis=1)
        distances = np.linalg.norm(deltas, axis=0)
        soma_ciclo_completo = np.sum(distances) + np.linalg.norm(x0[:, -1] - x0[:, 0])
        nn_cost = soma_ciclo_completo * xymax
        print(f"  [Initial solution] {nrepaired} visit point(s) repaired; "
              f"initial cost recomputed: {nn_cost}")

    # Plot of the TSPN instance and initial NN route
    plot_initial_tour(m, C, xpg, ypg, x0, nn_cost, xymax, instname)

    # Build features tables
    table_instance_features("tab-instance-features.txt", instname, m, ng, n, h, nbivar, nrevar, nlic, nquac)
    
    # =========================================================================
    # Provides the model with an initial solution
    # =========================================================================

    # mip_start_result = add_mip_start(m, xp, yp, U, tour0, x0, mdl, x, u, xi, gamma, px, py, w, lambdavar)
    if addconstraints:
        mip_start_result = add_mip_start(m, xp, yp, U, tour0, x0, mdl, x, u, xi, gamma, px, py, w, lambdavar, xix, xiy)
    else:
        mip_start_result = add_mip_start(m, xp, yp, U, tour0, x0, mdl, x, u, xi, gamma, px, py, w, lambdavar)
    # print(f"\nCheck initial solution: {mip_start_result}")
    # lp_file_path = f"modelo_tspn_{instname}.lp"
    # mdl.export_as_lp(lp_file_path)

    # =========================================================================
    # Solve the model
    # =========================================================================
    
    # A relative gap of 0, so that optimality is strict
    # mdl.parameters.mip.tolerances.mipgap = 0.0

    print("\n--- CPLEX SOLVER ---")
    try: 
        solution = mdl.solve(log_output=True) # log_output=True shows the log solver 
        
        # When 'solution' is None, look for the best feasible solution left in the model
        if solution is None:
            solution = mdl.solution

        if solution:
            
            print(f"Total Tour Length - original: {xymax * solution.get_objective_value():.4f}")
            print(f"Total Tour Length - scaled: {solution.get_objective_value():.4f}")

            try:
                print(f"Time: {solution.solve_details.time:.4f}")
                print(f"Status: {mdl.get_solve_status()}")
                print(solution.solve_details)    
            except:
                print("Execution details unavailable due to interruption.") 

            # Metapost file
            xsol = build_xsol_array(m, solution, x, px, py)
            draw_solution_metapost(m, C, xpg, ypg, xsol, instname, "plot-solutions-metapost")

            # Plot solver solution
            plot_model_solution(C, xpg, ypg, xymax, solution, x, px, py, instname)
        else:
            # If solution == None
            print("\n No feasible solution available (not even MIP Start was accepted).")
            print(f"Status: {mdl.get_solve_status()}")
    except Exception:
        if mdl.solution:
            solution = mdl.solution

    # Build tables
    table_model_solution("tab-cplex-solutions.txt", instname, mdl, solution, xymax)
    print_tour_xsol("tour-xsol-cplex-solutions.txt", instname, mdl, solution, x, w, px, py, m, U, xp, yp, xymax)

    mdl.end()
    del mdl
    del solution
    # import gc
    gc.collect()

# *******************************************************

def process_input_data_and_solve_model(instance_set, timelimit, solve_only_vispoints, normalize, addconstraints):
    
    for instname, instdata in instance_set.items():
        
        p = Process(
            target = solve_single_instance,
            args = (instname, instdata, timelimit, solve_only_vispoints, normalize, addconstraints)
        )
        
        p.start()
        p.join()   # wait for process to finish — OS frees *all* memory used
        
# *******************************************************
# ************************ Main *************************
# *******************************************************

def main():
    # Set the time limit to cplex solver
    timelimit = 3600

    # Wheter we wish to optimize only the visiting points to a given tour
    solve_only_vispoints = True

    # Wheter we wish to solve the stregthen model
    addconstraints = True

    # Wheter we wish do scale the points coordinates to the [-1,1] square
    normalize = False

    instance_set = read_all_instance_files('inst_cplex', 'inst-test')
    process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)
    
    # instance_set = read_all_instance_files('inst_cplex', 'inst-gtsp')
    # process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)

    # instance_set = read_all_instance_files('inst_cplex', 'inst-moml')
    # process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)
    
    # instance_set = read_all_instance_files('inst_cplex', 'inst-mom1')
    # process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)

    # instance_set = read_all_instance_files('inst_cplex', 'inst-mom2')
    # process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)

    # instance_set = read_all_instance_files('inst_cplex', 'inst-lar1')
    # process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)

    # instance_set = read_all_instance_files('inst_cplex', 'inst-lar2')
    # process_input_data_and_solve_model(instance_set,timelimit,solve_only_vispoints,normalize,addconstraints)

# ********************************************************

if __name__ == "__main__":
    main()