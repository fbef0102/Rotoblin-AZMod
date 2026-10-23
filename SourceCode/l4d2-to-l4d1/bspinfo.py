import struct,sys,re,zipfile,io,collections
def lumps(d):
    ver=struct.unpack('<i',d[4:8])[0]
    L=[]
    for i in range(64):
        a=struct.unpack('<iiii',d[8+16*i:24+16*i])
        if ver==21: v,ofs,ln,cc=a
        else: ofs,ln,v,cc=a
        L.append((ofs,ln,v,cc))
    return ver,L
def lump(d,L,i): o,l,v,cc=L[i]; return d[o:o+l]
def ents(d,L):
    t=lump(d,L,0).decode('latin1')
    out=[]
    for blk in re.findall(r'\{(.*?)\}',t,re.S):
        kv=dict(re.findall(r'"([^"]*)"\s+"([^"]*)"',blk)); 
        out.append((kv, re.findall(r'"([^"]*)"\s+"([^"]*)"',blk)))
    return out
def texdata(d,L):
    s=lump(d,L,43); tab=lump(d,L,44)
    offs=struct.unpack('<%di'%(len(tab)//4),tab)
    return sorted({s[o:s.index(b'\0',o)].decode('latin1').lower() for o in offs})
def gamelumps(d,L):
    g=lump(d,L,35); n=struct.unpack('<i',g[:4])[0]; out={}
    ver=struct.unpack('<i',d[4:8])[0]
    for i in range(n):
        gid,flags,v,ofs,ln=struct.unpack('<iHHii',g[4+16*i:20+16*i])
        out[gid.to_bytes(4,'big').decode('latin1')]=(v,ofs,ln)
    return out
def staticprops(d,L):
    gl=gamelumps(d,L)
    v,ofs,ln=gl['sprp']; b=d[ofs:ofs+ln]
    n=struct.unpack('<i',b[:4])[0]
    return v,[b[4+128*i:4+128*i+128].split(b'\0')[0].decode('latin1').lower() for i in range(n)]
def pak(d,L):
    try: return zipfile.ZipFile(io.BytesIO(lump(d,L,40))).namelist()
    except Exception as e: return ['ERR '+str(e)]
