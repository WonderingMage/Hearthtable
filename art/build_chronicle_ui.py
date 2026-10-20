"""Original sculpted-bronze, wine leather and illuminated-codex UI materials."""
from pathlib import Path
import math
import random
import json

OUT=Path(__file__).resolve().parents[1]/'assets/ui'
OUT.mkdir(exist_ok=True)
DEFS='''<defs>
<linearGradient id="metal" x2="0" y2="1"><stop stop-color="#f5dfaa"/><stop offset=".15" stop-color="#9f7136"/><stop offset=".37" stop-color="#e9c47b"/><stop offset=".52" stop-color="#6f4528"/><stop offset=".75" stop-color="#b88743"/><stop offset="1" stop-color="#ecd39a"/></linearGradient>
<linearGradient id="leather" x2=".3" y2="1"><stop stop-color="#3c2d28"/><stop offset=".48" stop-color="#201d21"/><stop offset="1" stop-color="#100f14"/></linearGradient>
<linearGradient id="wine" x2="0" y2="1"><stop stop-color="#7b3039"/><stop offset=".5" stop-color="#491d2b"/><stop offset="1" stop-color="#240e1c"/></linearGradient>
<linearGradient id="jade" x2="0" y2="1"><stop stop-color="#385854"/><stop offset="1" stop-color="#172b31"/></linearGradient>
<linearGradient id="vellum" x2="0" y2="1"><stop stop-color="#38322b"/><stop offset="1" stop-color="#1f2025"/></linearGradient>
<radialGradient id="gem"><stop stop-color="#e8d8a7"/><stop offset=".2" stop-color="#be9b62"/><stop offset=".5" stop-color="#8a3c31"/><stop offset="1" stop-color="#29121c"/></radialGradient>
</defs>'''
def svg(body,w=256,h=256):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>'
def curl(x,y,angle=0,scale=1):
    shape='''<path d="M3 39C5 18 16 5 37 3C29 7 26 14 29 20C33 28 45 25 42 17C39 9 29 16 35 19M8 32C18 34 24 28 24 21M12 23C19 22 21 15 21 11M16 16C9 15 7 22 8 28M26 7C24 0 17 2 16 8" fill="none" stroke="url(#metal)" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M4 36Q12 24 15 30Q20 36 4 36M12 24Q11 13 17 17Q23 23 12 24M24 9Q30 3 30 9Q28 15 24 9" fill="#b79559" stroke="#e7cd91" stroke-width=".5"/>
    <path d="M9 8L15 6L17 12L11 14Z" fill="url(#gem)" stroke="#d6b371" stroke-width="1.1"/>'''
    return f'<g transform="translate({x} {y}) rotate({angle}) scale({scale})">{shape}</g>'
def grain(w,h,seed=4):
    rng=random.Random(seed);body=''
    for _ in range(220):
        x=rng.randrange(22,w-22);y=rng.randrange(22,h-22)
        body+=f'<path d="M{x} {y}l{rng.randrange(1,11)} {rng.randrange(-2,3)}" stroke="#cab28b" opacity=".045" stroke-width=".7"/>'
    return body
def frame(kind):
    tall=kind in ['panel','tooltip','codex','portrait','slot','chapter'];edge=16 if tall else 9
    fill='wine' if kind in ['primary','pressed','ribbon'] else 'jade' if kind in ['selected','focus'] else 'vellum' if kind=='codex' else 'leather'
    stroke='#e2c585' if kind in ['primary','hover','selected','focus'] else '#957344'
    body=f'<rect x="2" y="3" width="252" height="252" rx="{edge}" fill="#08080c"/>'
    body+=f'<path d="M{edge} 5H{256-edge}L251 {edge}V{256-edge}L{256-edge} 251H{edge}L5 {256-edge}V{edge}Z" fill="url(#{fill})" stroke="#1c1110" stroke-width="7"/>'
    body+=grain(256,256)
    body+=f'<path d="M{edge} 5H{256-edge}L251 {edge}V{256-edge}L{256-edge} 251H{edge}L5 {256-edge}V{edge}Z" fill="none" stroke="url(#metal)" stroke-width="3"/>'
    body+=f'<rect x="11" y="11" width="234" height="234" rx="{max(2,edge-5)}" fill="none" stroke="{stroke}" stroke-width=".8"/>'
    body+='<path d="M22 16H234M16 22V234" stroke="#f0d39b" stroke-width="1" opacity=".22"/>'
    if tall:
        for x,y,angle in [(8,8,0),(248,8,90),(248,248,180),(8,248,270)]:body+=curl(x,y,angle,.7)
        for x,y in [(128,7),(128,249),(7,128),(249,128)]:body+=f'<path d="M{x} {y-4}l4 4-4 4-4-4Z" fill="url(#gem)" stroke="#c6a466" stroke-width="1"/>'
    else:
        for x in [14,242]:body+=f'<path d="M{x} 119l5 9-5 9-5-9Z" fill="url(#gem)" stroke="#b58b4c" stroke-width="1"/>'
    if kind=='disabled':body+='<rect x="5" y="5" width="246" height="246" rx="12" fill="#16161c" opacity=".66"/>'
    return svg(body)
for name in ['panel','tooltip','codex','portrait','slot','chapter','button','primary','pressed','selected','hover','focus','disabled','ribbon']:(OUT/f'{name}.svg').write_text(frame(name))
(OUT/'input.svg').write_text(svg('<rect x="2" y="2" width="252" height="252" rx="6" fill="#121018" stroke="#735939" stroke-width="2"/><path d="M8 246V8H246" fill="none" stroke="#08070b" stroke-width="6"/><path d="M10 248H248V10" fill="none" stroke="#b08b50" opacity=".42" stroke-width="1"/>'))
for kind,color in [('hp','#a63a42'),('resource','#b68e4d')]:
    (OUT/f'{kind}.svg').write_text(svg(f'<rect width="256" height="256" fill="#130e17"/><rect x="2" y="2" width="252" height="252" fill="{color}"/><path d="M0 5H256M0 15H256" stroke="#f7d797" stroke-width="2" opacity=".5"/><path d="M0 235H256" stroke="#351824" stroke-width="8"/>'))
body='<rect width="512" height="512" fill="#14121a"/>'
for i in range(0,512,32):body+=f'<path d="M{i} 0L512 {512-i}M0 {i}L{512-i} 512" stroke="#69513b" opacity=".055"/>'
for x,y in [(0,0),(256,0),(0,256),(256,256)]:
    body+=f'<g transform="translate({x} {y})" opacity=".075"><circle cx="128" cy="128" r="98" fill="none" stroke="#997341"/>'+curl(68,68,0,1.5)+'</g>'
(OUT/'screen.svg').write_text(svg(body,512,512))
body='<path d="M0 24H194L224 18L240 24L256 6L272 24L288 18L318 24H512" fill="none" stroke="url(#metal)" stroke-width="2"/>'
body+=curl(208,18,180,.65)+curl(304,30,0,.65)+'<path d="M256 10l10 14-10 14-10-14Z" fill="url(#gem)" stroke="#dabd82" stroke-width="1.5"/>'
(OUT/'divider.svg').write_text(svg(body,512,48))
# Reuse only the original illustration drawing functions, without running the
# older generator's asset-writing section or replacing these new UI materials.
library=Path(__file__).with_name('build_regalia.py');namespace={'__file__':str(library)}
exec(compile(library.read_text().split('SPELL_MOTIFS={}')[0],str(library),'exec'),namespace)
motif=namespace['motif'];group=namespace['group'];line=namespace['line'];path=namespace['path']
actions={
 'grapple':group(motif('hand'),'translate(-3 10) scale(.78)')+group(motif('chain'),'translate(34 27) scale(.67)'),
 'shoveprone':group(motif('head'),'translate(7 7) rotate(55 64 64) scale(.84)')+path('M29 27L48 27L48 52L58 52L39 74L20 52L29 52Z','url(#gold)'),
 'shovepush':group(motif('hand'),'translate(-10 5) scale(.85)')+path('M70 47L87 47L87 34L111 61L87 88L87 75L70 75Z','url(#gold)'),
 'helpattack':group(motif('sword'),'translate(8 8) scale(.88)')+group(motif('sun'),'translate(-6 -1) scale(.55)'),
 'helpcheck':group(motif('hand'),'translate(0 22) scale(.72)')+group(motif('rune'),'translate(48 -1) scale(.58)'),
 'escapegrapple':group(motif('chain'),'translate(2 1) scale(.95)')+path('M22 59L50 65L43 53L71 63L65 51L106 64','none','#fff2c9',5),
 'releasegrapple':group(motif('hand'),'translate(16 -2) scale(.96)')+path('M19 31L10 45L29 45M24 92L11 92L11 74','none','#fff2c9',4),
 'moreactions':group(motif('scroll'),'translate(0 2) scale(.97)'),
}
catalog_path=OUT.parent/'icons/catalog.json';catalog=json.loads(catalog_path.read_text())
for name,drawing in actions.items():
    defs='<defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#fff1bd"/><stop offset=".5" stop-color="#ba8840"/><stop offset="1" stop-color="#71503c"/></linearGradient><linearGradient id="ink" x2=".2" y2="1"><stop stop-color="#b5d0d1"/><stop offset="1" stop-color="#5b7a89"/></linearGradient><linearGradient id="dark" x2="0" y2="1"><stop stop-color="#25202e"/><stop offset="1" stop-color="#120f18"/></linearGradient></defs>'
    content='<rect x="3" y="3" width="122" height="122" rx="12" fill="url(#dark)" stroke="url(#gold)" stroke-width="3"/><circle cx="64" cy="64" r="45" fill="none" stroke="#765b42" stroke-width="1"/>'+drawing
    asset=OUT.parent/'icons/actions'/f'{name}.svg';asset.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128">{defs}{content}</svg>')
    catalog['actions'][name]={'path':f'res://assets/icons/actions/{name}.svg','motif':name}
catalog_path.write_text(json.dumps(catalog,indent=2)+'\n')
print('Wrote ornate fantasy interface materials.')
