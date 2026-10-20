#!/usr/bin/env python3
"""Package a full exported resource pack as one Settings-importable code update."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

MAGIC=b'HEARTHUPDATE01\n'

def build(pack: Path,output: Path,version: str,commit: str,protocol: int,changes=None):
    if not re.fullmatch(r'\d{1,3}\.\d{1,3}\.\d{1,3}',version) or not re.fullmatch(r'[0-9a-f]{40}',commit):
        raise ValueError('Expected a release version and exact clean source commit')
    data=pack.read_bytes()
    if len(data)<112 or len(data)>200_000_000 or data[:4]!=b'GDPC' or struct.unpack_from('<4I',data,4)!=(3,4,5,1) or not struct.unpack_from('<I',data,20)[0]&2:
        raise ValueError('Expected a Godot 4.5.1 resource pack with relative file offsets')
    if changes is None:changes=json.loads((Path(__file__).resolve().parents[1]/'docs/release-highlights.json').read_text())
    if not isinstance(changes,list) or not 1<=len(changes)<=80 or any(not isinstance(c,str) or len(c)>1000 for c in changes):raise ValueError('Expected bounded change descriptions')
    manifest={'format':1,'application':'Hearthtable Lite','version':version,'engine':'4.5.1','boot_api':1,'minimum_base':'1.0.0','protocol':protocol,'schema':1,'commit':commit,'pack_size':len(data),'sha256':hashlib.sha256(data).hexdigest(),'changes':changes}
    encoded=json.dumps(manifest,ensure_ascii=False,separators=(',',':')).encode()
    if len(encoded)>65536:raise ValueError('Manifest too large')
    with output.open('xb') as handle:handle.write(MAGIC+struct.pack('<I',len(encoded))+encoded+data)
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--version',required=True);parser.add_argument('--commit',required=True);parser.add_argument('--protocol',type=int,required=True)
    args=parser.parse_args();result=build(args.pack,args.output,args.version,args.commit,args.protocol)
    print(json.dumps({'file':str(args.output),'version':result['version'],'pack_bytes':result['pack_size'],'sha256':hashlib.sha256(args.output.read_bytes()).hexdigest()}))
