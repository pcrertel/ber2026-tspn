# validate-instance.awk -- checks the integrity of a polygonal TSPN instance.
#   usage: awk -v FN=file.dat -f validate-instance.awk file.dat
# Checks header consistency, token count, duplicate vertices, non-zero area,
# at most 3 reflex vertices, and absence of self-intersection (simple polygon).
BEGIN{ RS="[ \t\r\n]+" }
{ if($0!="") { n++; t[n]=$0+0 } }

function orient(ax,ay,bx,by,cx2,cy2,   v){
    v=(bx-ax)*(cy2-ay)-(by-ay)*(cx2-ax)
    if(v>1e-9) return 1; if(v<-1e-9) return -1; return 0
}
function onseg(ax,ay,bx,by,px,py){
    return (px>=(ax<bx?ax:bx)-1e-9 && px<=(ax>bx?ax:bx)+1e-9 &&
            py>=(ay<by?ay:by)-1e-9 && py<=(ay>by?ay:by)+1e-9)
}
function crosses(ax,ay,bx,by,cx2,cy2,dx2,dy2,   o1,o2,o3,o4){
    o1=orient(ax,ay,bx,by,cx2,cy2); o2=orient(ax,ay,bx,by,dx2,dy2)
    o3=orient(cx2,cy2,dx2,dy2,ax,ay); o4=orient(cx2,cy2,dx2,dy2,bx,by)
    if(o1!=o2 && o3!=o4) return 1
    if(o1==0 && onseg(ax,ay,bx,by,cx2,cy2)) return 1
    if(o2==0 && onseg(ax,ay,bx,by,dx2,dy2)) return 1
    if(o3==0 && onseg(cx2,cy2,dx2,dy2,ax,ay)) return 1
    if(o4==0 && onseg(cx2,cy2,dx2,dy2,bx,by)) return 1
    return 0
}

END{
    npol=t[1]; hdr=t[2]; p=3; errors=0; maxnv=0
    for(i=1;i<=npol;i++){
        nv=t[p]; p++
        if(nv<1){ printf "%s: polygon %d has nv=%d\n",FN,i,nv; errors++ }
        if(nv>maxnv) maxnv=nv
        for(j=1;j<=nv;j++){ X[j]=t[p]; Y[j]=t[p+1]; p+=2
            if(X[j]!=int(X[j]) || Y[j]!=int(Y[j])) nonint++ }
        # duplicate vertices
        for(j=1;j<=nv;j++) for(k=j+1;k<=nv;k++)
            if(X[j]==X[k] && Y[j]==Y[k]){ printf "%s: pol %d: vertices %d and %d are duplicates\n",FN,i,j,k; errors++ }
        if(nv<3) continue
        # non-zero area
        a=0; for(j=1;j<=nv;j++){ k=(j%nv)+1; a+=X[j]*Y[k]-X[k]*Y[j] }
        if(a<0)a=-a
        if(a/2.0 < 1e-9){ printf "%s: pol %d has zero area\n",FN,i; errors++ }
        # at most 3 reflex vertices (the signature of kinsert = 3 in stage 3)
        sgn=(a>=0?1:-1); refl=0
        for(j=1;j<=nv;j++){ k=(j%nv)+1; m=(k%nv)+1
            cr=(X[k]-X[j])*(Y[m]-Y[k])-(Y[k]-Y[j])*(X[m]-X[k])
            if(cr<-1e-9) refl++ }
        if(refl>3 && nv-refl>3){ printf "%s: pol %d has %d reflex vertices (>3)\n",FN,i,refl; errors++ }
        # self-intersection: pairs of non-adjacent edges
        if(nv>=4){
            for(j=1;j<=nv;j++){ jn=(j%nv)+1
                for(k=j+1;k<=nv;k++){ kn=(k%nv)+1
                    if(k==j || kn==j || k==jn || kn==jn) continue
                    if(crosses(X[j],Y[j],X[jn],Y[jn],X[k],Y[k],X[kn],Y[kn])){
                        printf "%s: pol %d: edges %d-%d and %d-%d cross\n",FN,i,j,jn,k,kn; errors++ } } }
        }
    }
    if(hdr!=maxnv){ printf "%s: header says nvmax=%d but the maximum is %d\n",FN,hdr,maxnv; errors++ }
    if(p-1!=n){ printf "%s: token count mismatch (read %d of %d)\n",FN,p-1,n; errors++ }
    if(nonint>0) printf "%s: warning -- %d vertices with a non-integer coordinate\n",FN,nonint
    if(errors==0) printf "%s: OK (npol=%d, nvmax=%d)\n",FN,npol,maxnv
    else printf "%s: %d PROBLEM(S)\n",FN,errors
}
