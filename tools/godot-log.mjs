// Godot 4.5.1 retains TLS verification using its bundled CA set if the
// Windows sandbox cannot open ROOT. Preserve raw logs; classify only that
// exact diagnostic, only with the pinned banner and verbose fallback proof.
import fs from 'node:fs';
const policy=JSON.parse(fs.readFileSync(new URL('./godot-log-policy.json',import.meta.url),'utf8'));
export function godotLog(raw,platform=process.platform) {
  let text=raw.replace(/\r\n/g,'\n');
  const errors=[...text.matchAll(new RegExp(policy.storeError,'gm'))];
  const fallback=platform==='win32' && errors.length===1 && new RegExp(policy.banner,'m').test(text) && [...text.matchAll(new RegExp(policy.fallback,'gm'))].length===1;
  if(fallback)text=text.replace(new RegExp(policy.storeError,'m'),'');
  return {failed:new RegExp(policy.bad,'m').test(text),builtinFallback:fallback};
}
