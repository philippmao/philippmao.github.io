import gdb

def chash_next(this):
    return int(gdb.execute(f"x/gx {hex(this)}",to_string=True).split(":")[-1],16)

def chash_check(this, fun_name, filename=None):
    found = False
    synname_addr = int(gdb.execute(f"x/gx {hex(this+0x8)}", to_string=True).split(":")[-1],16)
    filename_addr = int(gdb.execute(f"x/gx {hex(this+0x18)}", to_string=True).split(":")[-1],16)
    name =gdb.execute(f"x/s {hex(synname_addr)}", to_string=True)
    name = name[name.find(":")+1:]
    name = name.strip("\t")
    name = name.strip("\n")
    name = name.strip("\"")
    try:
        if fun_name == name:
            if filename is not None:
                if filename in gdb.execute(f"x/s {hex(filename_addr)}", to_string=True):
                    found=True 
            else:
                found=True
            if found:
                # found
                dbg_info = int(gdb.execute(f"x/gx {hex(this+40)}", to_string=True).split(":")[-1],16)
                fun_addr = int(gdb.execute(f"x/gx {hex(dbg_info+8)}", to_string=True).split(":")[-1],16)
                fun_addr = fun_addr & 0xffffffff
                return fun_addr
    except:
        pass
    return None

def hash_table_next(this):
    return int(gdb.execute(f"x/gx {hex(this)}",to_string=True).split(":")[-1],16)

def hash_table_chashes(this):
    out = []
    offset = 0
    chash_start = int(gdb.execute(f"x/gx {hex(this+0x18)}", to_string=True).split(":")[-1],16)
    max_off = int(gdb.execute(f"x/gx {hex(this+0x8)}", to_string=True).split(":")[-1],16)+1
    while(offset <= max_off*8):
        chash =int(gdb.execute(f"x/gx {hex(chash_start+offset)}", to_string=True).split(":")[-1],16)
        if chash!= 0:
            out.append(chash)
        offset += 8
    return out

class Uf(gdb.Command):
    """ 
    class CDbgInfo
    {
        U32   min_line,max_line;
        U32 body[1]; //Code heap is 32-bit value
        };

        public class CHashSrcSym:CHash
        {
        U8    *src_link,
        *idx;
        CDbgInfo *dbg_info;
        U8  *import_name;
        CAOTImportExport *ie_lst;
    };
    """

    def __init__(self):
        super(Uf, self).__init__("Uf", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        #TODO: walk 
        args = gdb.string_to_argv(arg)
        if len(args) < 1:
            print("usage: Uf <functionName> <filename>(optional)")
            print("partial filename is ok (no need for full path or HC ending") 
            return
        if len(args) >= 2:
            filename_hint = args[1]
        else:
            filename_hint = None
        # Fs->hash_table
        hash_table = int(gdb.execute("x/gx $fs_base + 0x3d0", to_string=True).split(":")[-1],16)
        while(1):
            #print(f"hash table: {hex(hash_table)}")
            for chash in hash_table_chashes(hash_table):
                #print(f"checking: {hex(chash)}")
                while(1):
                    #print(f"chash: {hex(chash)}")
                    fun_addr = chash_check(chash, args[0], filename=filename_hint)
                    if fun_addr is not None:
                        print(f"[!!] symbol found@{hex(fun_addr)}")
                    chash = chash_next(chash)
                    if chash == 0:
                        break
            hash_table = hash_table_next(hash_table)
            if hash_table == 0:
                break
        return

# Register the command with GDB
Uf()
