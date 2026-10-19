"""Original vector UI materials and semantic 2014 spell/weapon illustrations."""
from pathlib import Path
import json,math,hashlib,re,random
ROOT=Path(__file__).resolve().parents[1]/'assets';OUT=ROOT/'icons'
for folder in ['spells','weapons','actions','classes','creatures']:(OUT/folder).mkdir(parents=True,exist_ok=True)
(ROOT/'ui').mkdir(exist_ok=True)
def key(s):return re.sub('[^a-z]','',s.lower())
def path(d,fill='url(#ink)',stroke='#f5e2b1',width=1.3):return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'
def circle(x,y,r,fill='url(#ink)',stroke='#f5e2b1',width=1.4):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def line(x1,y1,x2,y2,color='#f5e2b1',w=2):return f'<path d="M{x1} {y1}L{x2} {y2}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round"/>'
def group(body,transform):return '<g transform="'+transform+'">'+body+'</g>'
def star(x,y,r=8):return path(f'M{x} {y-r}L{x+r*.25} {y-r*.25}L{x+r} {y}L{x+r*.25} {y+r*.25}L{x} {y+r}L{x-r*.25} {y+r*.25}L{x-r} {y}L{x-r*.25} {y-r*.25}Z')
def motif(name):
 if name=='crown':return path('M28 37L45 56L64 24L84 56L102 37L92 92L38 92Z','url(#gold)')+path('M39 81L91 81','none','#fff1c6',3)+circle(64,66,6)
 if name=='fireball':return circle(64,67,28)+path('M43 45Q33 21 51 16Q49 34 61 33Q73 5 84 18Q72 35 86 47L93 60L76 48L68 60L54 43Z','url(#gold)')+path('M42 65Q64 49 85 65M50 81Q65 71 77 83','none','#fff6d2',3)
 if name=='missiles':return group(motif('arrow'),'translate(-8 11) scale(.78)')+group(motif('arrow'),'translate(21 6) scale(.65)')+group(motif('arrow'),'translate(51 4) scale(.5)')
 if name=='handsfire':return group(motif('hand'),'translate(-6 27) scale(.62)')+group(motif('hand'),'translate(52 27) scale(.62)')+group(motif('flame'),'translate(27 -3) scale(.62)')
 if name=='counter':return motif('rune')+path('M29 30L99 96M99 30L29 96','none','#fff1b8',6)
 if name=='flame':return path('M63 17C76 39 47 40 70 58C82 49 82 36 82 36C103 65 88 91 65 94C36 95 26 73 41 52C43 70 56 64 51 49C45 34 60 27 63 17Z')+path('M64 55C78 70 80 83 64 89C48 83 53 70 64 55Z','#fff0ba','none')
 if name=='bolt':return path('M72 17L38 64L60 64L49 100L92 48L68 48L82 17Z')+line(46,31,31,43)+line(93,76,102,66)
 if name=='snow':
  s=''
  for a in range(0,360,60):s+=group(line(64,29,64,91)+path('M51 39L64 47L77 39M51 81L64 73L77 81','none'),f'rotate({a} 64 60)')
  return s+circle(64,60,7)
 if name=='shield':return path('M64 22L94 33L91 63Q85 84 64 96Q43 84 37 63L34 33Z')+path('M64 32L83 39L81 61Q77 75 64 84Q51 75 47 61L45 39Z','none','#fcf0c8',2)+star(64,56,12)
 if name=='sword':return group(path('M64 15L72 32L69 76L59 76L56 32Z')+line(64,30,64,74,'#fff4d6',2)+path('M43 74Q64 81 85 74L85 81L68 85L68 103L60 103L60 85L43 81Z','url(#gold)')+circle(64,107,4,'url(#gold)'), 'rotate(30 64 64)')
 if name=='arrow':return path('M83 20L94 44L79 39L43 90L35 85L71 34L56 33Z')+path('M37 79L25 79L30 98L49 97L47 87Z','url(#gold)')
 if name=='heart':return path('M64 38C45 15 24 43 36 59L64 90L92 59C106 40 83 18 64 38Z')+path('M48 59L58 59L64 46L70 71L75 59L85 59','none','#fff4d3',3)
 if name=='hand':return path('M48 92L35 63Q33 54 39 53L48 65L45 34Q46 26 52 30L57 54L57 25Q61 18 66 25L68 53L72 31Q78 25 81 33L77 58L84 45Q91 43 92 50L84 79L73 94Z')+path('M52 72Q64 64 76 69','none')
 if name=='eye':return path('M21 59Q63 15 107 59Q63 103 21 59Z')+circle(64,59,21,'url(#dark)')+circle(64,59,11)+circle(60,55,4,'#fff7de','none')
 if name=='head':return path('M45 98L45 78Q29 68 34 45Q39 23 62 25Q86 24 90 47L99 62L88 65L85 84L70 84L70 98Z')+path('M44 50Q52 36 66 45Q73 35 79 49M49 57Q61 48 75 58','none')
 if name=='skull':return path('M39 73Q24 52 39 32Q65 12 90 34Q104 53 89 73L84 79L84 94L45 94L45 79Z')+path('M41 53L58 51L56 65L43 65ZM72 51L89 53L87 65L73 65ZM64 68L58 78L70 78Z','url(#dark)','none')+path('M53 83L53 94M64 83L64 94M76 83L76 94','none','#675c55',2)
 if name=='sun':
  s=circle(64,60,21)
  for a in range(0,360,45):s+=group(path('M61 28L64 15L68 28Z','url(#gold)'),f'rotate({a} 64 60)')
  return s+circle(64,60,12,'#fff2c6','none')
 if name=='moon':return path('M78 23C39 22 26 57 44 79C58 99 83 96 96 80C55 90 42 47 78 23Z')+star(88,39,7)+star(76,62,5)
 if name=='cloud':return path('M33 84Q16 75 27 59Q29 39 48 44Q58 17 80 37Q103 33 102 55Q121 72 100 84Z')+path('M38 92L49 92M58 98L74 98M84 92L95 92','none')
 if name=='wave':return path('M19 79Q36 58 51 75Q65 26 96 35Q80 41 79 59Q101 49 111 69Q92 62 87 80Q70 98 52 84Q34 99 19 79Z')+path('M20 95Q35 86 49 95Q64 103 80 93Q96 85 110 93','none')
 if name=='leaf':return path('M31 92C30 41 64 20 99 21C96 66 75 87 31 92Z')+path('M35 88L87 35M54 68L51 47M70 52L69 34M53 70L75 73','none','#fbefca',2)
 if name=='tree':return path('M57 102L60 71L33 76L45 58L24 62L42 43L35 44L63 18L93 45L83 44L102 63L82 60L93 79L69 72L73 102Z')+path('M64 47L64 84M64 61L51 53M64 68L79 57','none')
 if name=='flower':
  s=''
  for a in range(0,360,72):s+=group(path('M64 62C42 52 38 27 54 25C68 24 70 40 64 62Z'),f'rotate({a} 64 60)')
  return s+circle(64,60,10,'url(#gold)')
 if name=='tentacle':return path('M39 103C17 81 37 69 64 69C93 68 84 40 66 44C58 47 59 54 67 53C53 70 41 50 51 36C73 8 113 47 90 76C78 91 51 83 54 102Z')+path('M41 92L49 89M45 80L53 79M67 77L71 72M85 65L88 59','none','#fff5ce',3)
 if name=='feather':return path('M30 99L42 70Q24 41 84 19Q106 51 55 79L30 99Z')+path('M35 94L80 29M47 77L45 55M57 63L58 42M60 62L80 59','none')
 if name=='wing':return path('M90 91Q36 103 24 40Q38 61 47 57Q28 34 37 20Q49 51 62 49Q51 25 62 17Q71 48 92 53Q111 61 90 91Z')+path('M42 67Q61 86 88 78M50 55Q63 67 92 67','none')
 if name=='paw':return circle(64,72,20)+circle(36,48,10)+circle(55,32,10)+circle(78,32,10)+circle(97,48,10)
 if name=='hound':return path('M30 87L35 60L29 25L50 40L78 37L97 24L93 61L82 91L64 103L45 95Z')+path('M42 58L55 63L48 68ZM73 63L85 57L81 68ZM54 80L74 80L64 91Z','url(#dark)','none')
 if name=='horse':return path('M40 99L45 73L31 68L40 50L57 35L58 19L70 31L80 23L82 43Q99 71 88 102L68 102L68 75L56 72L53 99Z')+circle(68,48,3,'url(#dark)','none')+path('M80 44L90 56L94 76','none')
 if name=='insect':return circle(64,64,23)+circle(64,33,10)+path('M44 52L29 36M41 65L22 65M44 78L31 93M84 52L99 36M87 65L106 65M84 78L97 93M64 44L64 87','none','#f5e2b1',3)
 if name=='spider':return circle(64,69,18)+circle(64,43,11)+path('M49 43L34 29L23 39M45 55L25 48L17 60M45 70L26 78L21 94M50 81L40 95L45 107M79 43L94 29L105 39M83 55L103 48L111 60M83 70L102 78L107 94M78 81L88 95L83 107','none','#f5e2b1',3)
 if name=='bird':return path('M22 42L50 53Q58 28 74 39L92 35L84 47L107 65L79 63Q74 83 51 92L62 68Q32 72 22 42Z')+circle(73,43,2,'url(#dark)','none')
 if name=='butterfly':return path('M62 56Q30 16 23 43Q17 67 50 67Q23 78 35 94Q56 107 63 71Q73 108 95 94Q105 77 80 67Q110 68 104 43Q98 18 67 56Z')+path('M64 44L64 88M63 47L53 32M65 47L76 32','none','#fff5ce',3)
 if name=='book':return path('M64 39Q41 24 23 32L23 91Q42 84 64 97Q86 84 105 91L105 32Q87 24 64 39Z')+path('M64 39L64 97M32 45Q44 41 55 48M32 58Q44 54 55 61M73 48Q86 41 97 45M73 61Q86 54 97 58','none','#fff1c6',2)
 if name=='scroll':return path('M39 27L91 27Q109 30 99 47L89 47L86 88Q82 105 63 96L29 96Q15 82 32 76L38 76Z')+path('M51 44L79 44M50 56L77 56M48 68L75 68M38 77L70 77M90 28Q81 32 89 47M31 77Q44 83 37 95','none','#fff1c6',2)
 if name=='door':return path('M32 103L32 48Q64 1 96 48L96 103L84 103L84 50Q64 24 44 50L44 103Z')+path('M49 53L80 45L80 103L49 96Z','url(#dark)')+circle(72,75,3,'url(#gold)')
 if name=='portal':return '<ellipse cx="64" cy="61" rx="29" ry="42" fill="url(#dark)" stroke="url(#ink)" stroke-width="9"/>'+path('M55 29Q25 62 57 93M76 31Q99 61 77 91','none','#fff2ca',2)+star(64,61,16)
 if name=='lock':return path('M44 52L44 38Q64 10 84 38L84 52L75 52L75 40Q64 25 53 40L53 52Z','url(#gold)')+path('M35 52L93 52L93 96L35 96Z')+circle(64,70,7,'url(#dark)')+path('M61 74L58 88L70 88L67 74Z','url(#dark)','none')
 if name=='key':return circle(51,45,20,'none','#f5e2b1',9)+path('M65 58L95 92L89 100L80 91L75 96L67 88L73 82L59 64Z','url(#gold)')
 if name=='chain':return group('<rect x="49" y="19" width="30" height="46" rx="13" fill="none" stroke="url(#ink)" stroke-width="8"/><rect x="49" y="58" width="30" height="46" rx="13" fill="none" stroke="url(#ink)" stroke-width="8"/>','rotate(35 64 64)')
 if name=='cage':return path('M25 95L25 51Q64 10 103 51L103 95Z','url(#dark)')+path('M25 51L103 51M37 41L37 95M54 32L54 95M74 32L74 95M91 41L91 95M23 96L105 96','none','#f5e2b1',3)
 if name=='web':
  s=''
  for a in range(0,360,45):s+=group(line(64,60,64,16,'#f5e2b1',1.6),f'rotate({a} 64 60)')
  for r in [13,26,39]:s+=path('M64 '+str(60-r)+'Q'+str(64+r*.1)+' '+str(60-r*.1)+' '+str(64+r)+' 60Q'+str(64+r*.1)+' '+str(60+r*.1)+' 64 '+str(60+r)+'Q'+str(64-r*.1)+' '+str(60+r*.1)+' '+str(64-r)+' 60Q'+str(64-r*.1)+' '+str(60-r*.1)+' 64 '+str(60-r)+'Z','none')
  return s
 if name=='rope':return path('M36 100L37 55Q37 24 66 24Q98 25 96 52Q91 75 68 67Q51 61 60 47Q74 32 84 49','none','#e4cc95',7)+path('M34 83L41 87M34 68L41 72M42 40L49 43','none','#8a623e',2)
 if name=='wand':return path('M34 96L79 42L85 47L41 102Z','url(#gold)')+star(90,33,18)+star(48,34,6)+star(94,77,6)
 if name=='meteor':return path('M43 87L94 20L85 66Z')+circle(47,80,22)+path('M35 72L49 67L58 81L44 92Z','url(#gold)')+path('M24 46L45 21M85 87L106 62','none')
 if name=='mouth':return path('M22 60Q43 40 64 49Q86 40 106 60Q84 89 64 85Q43 89 22 60Z')+path('M29 60Q64 68 99 60Q67 84 29 60Z','url(#dark)')+path('M38 60L42 69L48 62M81 63L87 70L90 61','none')
 if name=='mask':return path('M28 24Q64 39 100 24L96 64Q89 90 64 102Q36 89 31 64Z')+path('M39 51Q48 40 57 53L53 64L40 61ZM71 53Q80 40 89 51L88 61L75 64Z','url(#dark)','none')+path('M48 79Q64 92 81 78','none','#f5e2b1',3)
 if name=='mountain':return path('M15 97L46 35L66 63L84 21L115 97Z')+path('M35 55L46 35L58 52L47 49ZM73 48L84 21L96 49L84 43Z','#fff1cc','none')
 if name=='clock':return circle(64,62,34)+circle(64,62,27,'url(#dark)')+path('M64 39L64 62L81 74M60 17L68 17M61 25L67 25','none','#fff4d0',4)+circle(64,62,4,'url(#gold)')
 if name=='mirror':return '<ellipse cx="64" cy="52" rx="27" ry="34" fill="url(#ink)" stroke="url(#gold)" stroke-width="6"/>'+path('M58 86L57 103L71 103L70 86M51 50L71 32M55 67L78 43','none','#fff3d5',3)
 if name=='crystal':return path('M64 16L92 44L83 86L64 106L43 84L36 44Z')+path('M64 16L54 44L64 106L75 44L64 16M37 44L91 44M43 84L64 74L84 86','none','#fff3d5',1.8)
 if name=='jar':return path('M46 24L82 24L82 34L77 34L77 47Q108 76 89 99L39 99Q20 76 51 47L51 34L46 34Z')+path('M39 74Q55 65 72 76Q82 81 94 74L89 95L39 95Z','url(#dark)')+circle(64,83,6)
 if name=='feast':return path('M31 32L97 32L90 60Q86 73 68 78L68 94L86 99L86 104L42 104L42 99L60 94L60 78Q40 73 37 60Z')+path('M41 40L87 40M46 48L49 60','none','#fff6da',2)+star(64,56,12)
 if name=='rune':return path('M64 19L105 89L23 89Z','none','#f5e2b1',3)+circle(64,62,24,'none','#f5e2b1',2)+path('M43 62L85 62M64 39L64 86','none')
 if name=='anvil':return path('M18 44L53 44L53 32L105 32L105 48L91 58L84 85L100 94L100 101L38 101L38 94L54 85L50 65L30 61Z')+path('M57 40L94 40','none','#fff5cc',3)
 if name=='ear':return path('M42 83Q40 101 58 101Q76 99 73 83Q76 72 87 66Q106 43 86 25Q64 8 43 30L38 48L47 52Q48 24 70 28Q98 35 80 57L64 66L63 84Q56 96 50 82Z')
 if name=='foot':return path('M38 96L38 81L49 62L52 27Q63 17 74 30L77 67L96 83Q105 92 96 99L57 102Z')+path('M49 60L75 65M44 85L88 89','none')
 if name=='scales':return path('M60 23L68 23L68 41L99 36L103 42L68 48L68 94L88 98L88 103L40 103L40 98L60 94L60 49L26 54L24 47L60 41Z','url(#gold)')+path('M29 54L17 79Q30 91 44 79ZM97 43L83 69Q96 82 110 69Z')
 if name=='bell':return path('M33 80L40 69L43 43Q45 26 61 25L61 18L68 18L68 25Q85 29 87 43L91 69L97 80Z')+path('M48 88Q64 106 80 88Z','url(#gold)')
 if name=='chest':return path('M27 53L27 39Q64 12 101 39L101 93L27 93Z')+path('M27 53L101 53M41 30L41 91M87 30L87 91','none','#d0ae64',4)+path('M57 49L72 49L72 70L57 70Z','url(#gold)')
 if name=='wall':return path('M24 101L24 40L64 24L103 40L103 101Z')+path('M24 59L103 59M24 79L103 79M43 34L43 59M82 34L82 59M64 59L64 79M43 79L43 101M82 79L82 101','none','#4e4d4e',3)
 if name=='flask':return path('M52 21L77 21L77 30L72 30L72 53L98 91Q103 104 91 104L36 104Q24 104 32 91L57 53L57 30L52 30Z')+path('M45 76L83 76L97 97L31 97Z','url(#dark)')+circle(62,84,4)
 if name=='wind':return path('M24 43L79 43Q99 43 96 28Q90 12 79 26M19 60L94 60Q116 59 107 42M28 77L70 77Q95 77 87 97Q79 110 68 94','none','#f5e2b1',5)
 return star(64,60,35)+circle(64,60,13)

SPELL_MOTIFS={}
def assign(m,names):
 for n in names.split('|'):
  k=key(n.strip())
  if k:SPELL_MOTIFS[k]=m
assign('arrow','Acid Arrow|Guiding Bolt|Fire Bolt|Ray of Frost|Ray of Enfeeblement|Scorching Ray|True Strike')
assign('flask','Acid Splash|Grease|Poison Spray|Detect Poison and Disease|Purify Food and Drink|Protection from Poison|Contagion')
assign('heart','Aid|Cure Wounds|Mass Cure Wounds|Heal|Mass Heal|Healing Word|Mass Healing Word|Prayer of Healing|Regenerate|Lesser Restoration|Greater Restoration|False Life|Spare the Dying')
assign('bell','Alarm|Silence|Knock|Shatter|Thunderwave')
assign('butterfly','Alter Self|Animal Shapes|Polymorph|True Polymorph|Shapechange|Reincarnate')
assign('paw','Animal Friendship|Dominate Beast|Conjure Animals|Find Familiar|Locate Animals or Plants|Speak with Animals|Animal Messenger')
assign('skull','Animate Dead|Create Undead|Circle of Death|Finger of Death|Power Word Kill|Raise Dead|Resurrection|True Resurrection|Revivify|Blight|Speak with Dead|Gentle Repose')
assign('wand','Animate Objects|Awaken|Creation|Prestidigitation|Thaumaturgy|Wish|Instant Summons|Unseen Servant|Druidcraft')
assign('shield','Antilife Shell|Antimagic Field|Death Ward|Shield|Shield of Faith|Mage Armor|Barkskin|Stoneskin|Fire Shield|Protection From Energy|Protection from Evil and Good|Sanctuary|Resistance|Warding Bond|Globe of Invulnerability|Nondetection|Mind Blank|Private Sanctum|Forbiddance|Guards and Wards|Hallow|Holy Aura')
assign('mask','Antipathy/Sympathy|Disguise Self|Seeming|Fear|Phantasmal Killer|Weird|Invisibility|Greater Invisibility|Mislead|Blur|Blink')
assign('eye','Arcane Eye|Arcanist\'s Magic Aura|Clairvoyance|Darkvision|Detect Evil and Good|Detect Magic|Detect Thoughts|Divination|Foresight|Identify|Scrying|See Invisibility|True Seeing|Eyebite|Find Traps')
assign('hand','Arcane Hand|Mage Hand|Telekinesis|Chill Touch|Vampiric Touch|Shocking Grasp|Inflict Wounds|Harm')
assign('lock','Arcane Lock|Arcane Sword|Planar Binding|Hold Monster|Hold Person|Imprisonment|Sequester|Planar Ally|Geas|Magic Circle')
assign('portal','Astral Projection|Banishment|Demiplane|Dimension Door|Etherealness|Gate|Plane Shift|Teleport|Teleportation Circle|Word of Recall|Misty Step|Transport via Plants|Tree Stride')
assign('book','Augury|Comprehend Languages|Commune|Commune With Nature|Contact Other Plane|Legend Lore|Tongues|Message|Sending|Illusory Script|Symbol|Glyph of Warding|Contingency')
assign('head','Bane|Bestow Curse|Blindness/Deafness|Calm Emotions|Charm Person|Command|Compulsion|Confusion|Dominate Monster|Dominate Person|Dream|Enthrall|Enhance Ability|Feeblemind|Glibness|Hideous Laughter|Hunter\'s Mark|Hypnotic Pattern|Irresistible Dance|Mass Suggestion|Modify Memory|Power Word Stun|Remove Curse|Suggestion|Telepathic Bond|Vicious Mockery')
assign('tentacle','Black Tentacles')
assign('sword','Blade Barrier|Branding Smite|Divine Favor|Magic Weapon|Spiritual Weapon|Flame Blade|Shillelagh')
assign('sun','Beacon of Hope|Bless|Daylight|Light|Sunbeam|Sunburst|Sacred Flame|Divine Word|Heroism|Guidance|Guardian of Faith|Spirit Guardians|Conjure Celestial')
assign('flame','Burning Hands|Continual Flame|Delayed Blast Fireball|Fire Storm|Fireball|Flame Strike|Flaming Sphere|Heat Metal|Hellish Rebuke|Incendiary Cloud|Produce Flame|Wall of Fire|Faerie Fire')
assign('bolt','Call Lightning|Chain Lightning|Lightning Bolt|Storm of Vengeance|Eldritch Blast|Magic Missile|Disintegrate|Counterspell|Dispel Evil and Good|Dispel Magic')
assign('cloud','Cloudkill|Control Weather|Dancing Lights|Darkness|Fog Cloud|Gaseous Form|Stinking Cloud|Wind Walk')
assign('snow','Cone of Cold|Freezing Sphere|Ice Storm|Sleet Storm|Wall of Ice|Simulacrum')
assign('rune','Conjure Elemental|Conjure Fey|Conjure Minor Elementals|Conjure Woodland Beings|Minor Illusion|Major Image|Programmed Illusion|Silent Image|Color Spray|Prismatic Spray|Prismatic Wall')
assign('wave','Control Water|Create or Destroy Water|Water Breathing|Water Walk')
assign('feast','Create Food and Water|Heroes\' Feast|Goodberry')
assign('mountain','Earthquake|Hallucinatory Terrain|Mirage Arcane|Move Earth|Meld Into Stone|Flesh to Stone|Stone Shape|Wall of Stone')
assign('leaf','Entangle|Plant Growth|Speak with Plants|Pass Without Trace|Spike Growth|Wall of Thorns')
assign('foot','Enlarge/Reduce|Expeditious Retreat|Freedom of Movement|Find the Path|Haste|Jump|Longstrider|Slow')
assign('anvil','Fabricate|Mending')
assign('hound','Faithful Hound')
assign('feather','Feather Fall|Fly|Levitate|Reverse Gravity')
assign('horse','Find Steed|Phantom Steed')
assign('mirror','Floating Disk|Mirror Image|Project Image|Magic Mouth|Magic Jar')
assign('cage','Forcecage|Resilient Sphere|Wall of Force')
assign('insect','Giant Insect|Insect Plague')
assign('wind','Gust of Wind|Wind Wall')
assign('moon','Sleep|Moonbeam')
assign('door','Magnificent Mansion|Maze|Passwall|Tiny Hut')
assign('meteor','Meteor Swarm')
assign('rope','Rope Trick')
assign('chest','Secret Chest')
assign('spider','Spider Climb|Web')
assign('clock','Time Stop')
assign('scales','Zone of Truth')

assign('jar','Clone')
assign('eye','Locate Creature|Locate Object')
assign('fireball','Fireball|Delayed Blast Fireball|Flaming Sphere')
assign('missiles','Magic Missile|Scorching Ray')
assign('handsfire','Burning Hands')
assign('counter','Counterspell|Dispel Magic')

SCHOOLS={'Abjuration':('#83cbd8','#315b87'),'Conjuration':('#90d6a2','#2d5b62'),'Divination':('#e5d38e','#877636'),'Enchantment':('#ed9dc2','#79456c'),'Evocation':('#f4ba84','#9e4b35'),'Illusion':('#c0a6ed','#535583'),'Necromancy':('#abcf82','#496747'),'Transmutation':('#dfbe83','#806340')}
def spell_palette(s):
 n=s['name'].lower()
 for words,colors in [('fire|flam|burn|heat|incendiary|hellish',('#ffd48f','#bc4930')),('cold|frost|ice|sleet|freezing',('#dcf8ff','#4b98d3')),('lightning|thunder|shocking|storm',('#f6e9ae','#7460bd')),('acid|poison|contagion|blight',('#d8ef7d','#599f49')),('heal|cure|restoration|reviv|resur|aid|regenerate',('#fff0b8','#ba8e3d')),('force|arcane|magic|eldritch',('#d5b9ff','#7550bd')),('water|wave|wind|fog|gaseous',('#bce9f4','#4b99ad')),('sun|holy|sacred|divine|bless|faith',('#fff1bb','#c38e37'))]:
  if any(w in n for w in words.split('|')):return colors
 return SCHOOLS[s['school']['name']]
def secondary(s,primary):
 n=s['name'].lower()
 overrides={'cure wounds':'hand','mass cure wounds':'hand','healing word':'mouth','mass healing word':'mouth','bless':'hand','fire bolt':'flame','scorching ray':'flame','magic missile':'rune','animate dead':'hand','raise dead':'sun','resurrection':'wing','true resurrection':'crown','find familiar':'rune','conjure animals':'leaf','animal friendship':'heart','animal messenger':'bird','haste':'clock','slow':'clock','jump':'wing','misty step':'cloud','mage armor':'head','shield of faith':'sun','shatter':'crystal','sleep':'head','polymorph':'hound','true polymorph':'crown','magic jar':'jar','magic mouth':'mouth','speak with dead':'mouth','revivify':'heart','goodberry':'leaf','greater invisibility':'eye','invisibility':'moon'}
 if n in overrides and overrides[n]!=primary:return overrides[n]
 semantic=[('fire|flame|burn|heat','flame'),('ice|frost|cold|sleet','snow'),('lightning|shocking','bolt'),('dead|death|dying|kill|undead','skull'),('faith|holy|divine|bless|good','sun'),('poison|acid|disease','flask'),('mind|thought|memory|mental','head'),('person|monster|self|shape','head'),('animal|beast|familiar','paw'),('plants|nature|thorn|wood','leaf'),('wind|air|gust','wind'),('water','wave'),('shield|protection|ward|resistance','shield'),('word|speak|command|message|languages|tongues|laughter|mockery','mouth'),('true|detect|seeing|scry|identify','eye'),('light|radiant|hope','sun'),('mass|circle|sphere|globe','rune'),('greater|power|wish','crown')]
 for words,m in semantic:
  if m!=primary and any(w in n for w in words.split('|')):return m
 return ['star','crystal','moon','rune','wing','key','eye','heart'][int(hashlib.sha256(n.encode()).hexdigest()[:4],16)%8]
def icon(name,primary,colors,secondary_m=None,level=0,school='',kind='spell'):
 seed=int(hashlib.sha256((kind+name).encode()).hexdigest()[:8],16);rnd=random.Random(seed)
 high,low=colors
 defs=f'''<defs><linearGradient id="ink" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{high}"/><stop offset=".45" stop-color="{high}"/><stop offset="1" stop-color="{low}"/></linearGradient><linearGradient id="gold" x1="0" y1="0" x2=".9" y2="1"><stop stop-color="#fae6ac"/><stop offset=".4" stop-color="#b99550"/><stop offset=".7" stop-color="#e6cc83"/><stop offset="1" stop-color="#69502c"/></linearGradient><radialGradient id="dark"><stop stop-color="{low}"/><stop offset="1" stop-color="#17202b"/></radialGradient><radialGradient id="halo"><stop stop-color="{low}" stop-opacity=".65"/><stop offset="1" stop-color="{low}" stop-opacity="0"/></radialGradient></defs>'''
 body='<path d="M11 4H117L124 11V117L117 124H11L4 117V11Z" fill="#0b1017" stroke="#9f8247" stroke-width="1.6"/><path d="M14 9H114L119 14V114L114 119H14L9 114V14Z" fill="url(#dark)" stroke="#4d4b44"/>'
 body+=circle(64,61,53,'url(#halo)','none')
 # Faint school constellation and material grain, behind the semantic artwork.
 body+='<g opacity=".12">'+circle(64,61,43,'none',high,1)+path('M25 37L103 84M25 84L103 37M64 17L64 105','none',high,1)+'</g>'
 for _ in range(24):
  x,y=rnd.randint(15,112),rnd.randint(15,112);body+=circle(x,y,rnd.choice([.4,.65,.9]),high,'none').replace('/>',' opacity=".13"/>')
 art=motif(primary)
 # A semantic second glyph creates a recognisable compound, not a recoloured generic star.
 if secondary_m:
  art=group(art,'translate(-2 -5) scale(.88)')+group(motif(secondary_m),'translate(71 68) scale(.34)')
 if name.lower().startswith('mass '):art=group(art,'translate(15 5) scale(.78)')+group(motif('heart'),'translate(-2 62) scale(.28)')
 # Shadow relief, bright artwork and a deliberately light top engraving.
 body+=group(art,'translate(1.8 2.8)').replace('url(#ink)','#080c13').replace('url(#gold)','#080c13').replace('#f5e2b1','#080c13')
 body+=art
 # Each catalogue entry has a fixed constellation at the lower rim; no text at small scale.
 for i in range(3):
  if seed & (1<<i):body+=star(42+i*22,112,2.1)
 body+=path('M12 25V13H25M103 13H115V25M12 103V115H25M103 115H115V103','none','url(#gold)',1.4)
 if level:body+=circle(112,16,6,'url(#gold)','#f6e7b5',.7)+path('M110 13L114 16L110 19Z','#403027','none')
 return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128">'+defs+body+'</svg>'

def weapon_art(n):
 # Anatomically different profiles for every standard weapon, not one shared sword.
 shaft=lambda length=90: path(f'M60 18L66 18L66 {length}L60 {length}Z','#ad7846','#e6c28b',1.2)
 steel='url(#ink)';gold='url(#gold)'
 if n in ['longsword','shortsword','greatsword','dagger','rapier','scimitar']:
  length={'dagger':46,'shortsword':60,'longsword':75,'greatsword':84,'rapier':84,'scimitar':76}[n];bottom=100;top=bottom-length
  width={'dagger':9,'shortsword':10,'longsword':9,'greatsword':13,'rapier':3,'scimitar':10}[n]
  art=path(f'M63 {top}L{63+width} {top+17}L{63+width*.7} 83L{63-width*.7} 83L{63-width} {top+17}Z')+line(63,top+13,63,82,'#fff1c7',1.5)
  if n=='scimitar':art=path('M81 16Q93 57 68 85L55 83Q79 45 81 16Z')
  art+=path('M43 81Q63 87 83 81L83 87L67 91L67 107L59 107L59 91L43 87Z',gold)+circle(63,109,4,gold)
  if n=='rapier':art+=path('M44 83Q45 103 65 100Q83 98 82 83','none','#ecd394',3)
  if n=='greatsword':art+=path('M50 72L76 72M54 99L72 99','none','#f3d88d',3)
  return group(art,'rotate(32 64 64)')
 if 'axe' in n or n in ['glaive','halberd']:
  art=shaft(111)
  if n=='glaive':art+=path('M65 14Q96 22 84 56L65 68Z')
  elif n=='halberd':art+=path('M63 8L70 27L98 33L96 61L70 56L64 72L58 55L36 57L45 40L57 38Z')
  else:
   art+=path('M67 28Q84 35 99 26L98 64Q81 55 67 59Z')
   if n in ['battleaxe','greataxe']:art+=path('M60 28Q42 35 27 26L28 64Q45 55 60 59Z')
   if n=='greataxe':art+=path('M63 10L72 30L63 44L54 30Z')
  return group(art,'rotate(28 64 64)')
 if n in ['spear','javelin','pike','lance','trident']:
  art=shaft(111)
  art+=path('M63 10L73 39L64 51L53 39Z')
  if n=='lance':art+=path('M63 12L77 78L49 78Z')+path('M44 87Q63 75 82 87L77 95L49 95Z',gold)
  if n=='trident':art+=path('M41 14L40 44Q64 67 87 44L86 14L80 27L80 41Q64 56 47 41L47 27Z')
  if n=='pike':art+=path('M55 45L71 45L71 62L55 62Z',gold)
  if n=='javelin':art+=path('M59 87L70 84M59 92L70 89M59 97L70 94','none','#ead6a0',2)
  return group(art,'rotate(33 64 64)')
 if n in ['club','greatclub','quarterstaff']:
  art=path('M59 105L69 105L75 38Q80 14 63 15Q48 15 51 38Z','#ac794b','#e5c091',1.5)
  if n=='quarterstaff':art=shaft(110)+path('M58 15L68 15L68 30L58 30ZM58 96L68 96L68 110L58 110Z',gold)
  elif n=='greatclub':art=path('M58 110L71 110L77 68L88 49L82 18L48 17L40 49L52 69Z','#9b724d')+path('M50 33L54 56M69 28L72 60','none','#dcc193',2)
  else:art+=path('M57 34L69 32M56 47L70 44M58 60L69 56','none','#6b4d38',3)
  return group(art,'rotate(30 64 64)')
 if n in ['mace','morningstar','flail']:
  art=shaft(108)
  if n=='flail':art=path('M33 108L41 108L56 68L49 65Z','#b08550')+path('M52 66Q95 64 85 32','none','#efcf8e',4)
  art+=circle(84 if n=='flail' else 64,30,18)
  if n=='morningstar' or n=='flail':
   cx=84 if n=='flail' else 64
   for a in range(0,360,60):art+=group(path(f'M{cx-5} 15L{cx} 2L{cx+5} 15Z'),f'rotate({a} {cx} 30)')
  else:art+=path('M45 23L50 15L78 15L83 23L83 43L45 43Z')+line(57,15,57,43)+line(70,15,70,43)
  return group(art,'rotate(25 64 64)')
 if n in ['warhammer','lighthammer','maul','warpick']:
  art=shaft(110)
  if n=='warpick':art+=path('M35 31Q69 15 101 43L75 35L68 51L53 45L52 33L36 40Z')
  else:
   half=27 if n=='maul' else 23 if n=='warhammer' else 17
   art+=path(f'M{64-half} 20L{64+half} 20L{68+half} 26L{68+half} 48L{60-half} 48L{60-half} 26Z')
   art+=path(f'M{64-half+4} 24L{64-half+4} 44M{64+half-3} 24L{64+half-3} 44','none','#e4ce9d',3)
  return group(art,'rotate(26 64 64)')
 if n in ['sickle','whip']:
  if n=='whip':return path('M32 105L45 75L51 78L38 110Z',gold)+path('M48 76Q15 39 53 22Q105 5 103 52Q104 81 80 91Q63 100 69 81','none','#c29363',6)
  return group(shaft(107)+path('M65 50C111 41 91 4 54 19C81 23 91 36 66 39Z'),'rotate(20 64 64)')
 if n in ['shortbow','longbow']:
  wide=30 if n=='longbow' else 22
  return path(f'M39 15Q{39+wide*2} 59 39 108','none','#c39b61',7)+path('M39 15L57 62L39 108','none','#eae1c9',1.5)+path('M28 65L103 39L91 36L98 47L102 40','none','#e8dbb4',2)
 if 'crossbow' in n:
  scale=.85 if n=='handcrossbow' else 1
  art=path('M26 39Q65 60 104 40','none','#b28351',7)+path('M26 39L64 76L104 40','none','#efdcaf',1.5)+path('M58 24L70 24L70 88L80 100L67 110L54 91Z','#8f6640')+path('M64 14L64 78M59 23L64 14L69 23','none','#f9ecc9',2)
  if n=='heavycrossbow':art+=path('M43 56L85 56L85 65L43 65Z')+circle(78,83,8,'none','#bea269',2)
  return group(art,f'translate({64*(1-scale)} {64*(1-scale)}) scale({scale})')
 if n=='sling':return path('M35 18L59 62L75 62L96 20M59 62L46 91Q67 114 86 90L75 62','none','#b28e60',5)+circle(66,83,13,'#8c9497','#e4d4b1')
 if n=='net':
  art=path('M31 25L98 38L85 102L20 89Z','none','#e7d5a1',3)
  for i in range(4):art+=line(31+i*16,26+i*3,20+i*16,89+i*3,'#c8ad76',2)+line(28-i*3,39+i*16,95-i*3,52+i*16,'#c8ad76',2)
  return art
 if n=='dart':return group(path('M64 15L70 35L66 82L79 100L64 96L49 100L61 82L58 35Z'),'rotate(30 64 64)')
 if n=='blowgun':return group(path('M58 14L69 14L69 105L58 105Z','#8c633a')+path('M57 14L70 14L70 25L57 25ZM57 95L70 95L70 105L57 105Z',gold)+line(88,35,88,92,'#d6d3bd',2),'rotate(30 64 64)')
 return motif('hand')

def weapon_icon(n):
 # Reuse the same relief frame, replace only semantic art through a temporary motif hook.
 global motif
 original=motif
 motif=lambda m:weapon_art(n) if m=='weapon' else original(m)
 result=icon(n,'weapon',('#e9e4ce','#748897'),kind='weapon')
 motif=original
 return result

spells=json.loads((ROOT/'spells.json').read_text());manifest={'spells':{},'weapons':{},'actions':{},'classes':{},'creatures':{}}
missing=[s['name'] for s in spells if key(s['name']) not in SPELL_MOTIFS]
assert not missing,missing
for s in spells:
 k=key(s['name']);primary=SPELL_MOTIFS[k];second=secondary(s,primary);file='spells/'+s['index']+'.svg'
 (OUT/file).write_text(icon(s['name'],primary,spell_palette(s),second,s['level'],s['school']['name']))
 manifest['spells'][k]={'path':'res://assets/icons/'+file,'name':s['name'],'motif':primary,'secondary':second,'school':s['school']['name']}
weapons='club dagger greatclub handaxe javelin lighthammer mace quarterstaff sickle spear lightcrossbow dart shortbow sling battleaxe flail glaive greataxe greatsword halberd lance longsword maul morningstar pike rapier scimitar shortsword trident warpick warhammer whip blowgun handcrossbow heavycrossbow longbow net unarmedstrike'.split()
for n in weapons:
 file='weapons/'+n+'.svg';(OUT/file).write_text(weapon_icon(n));manifest['weapons'][n]={'path':'res://assets/icons/'+file,'name':n}
actions={'attack':('sword','star'),'spell':('wand','star'),'move':('foot','arrow'),'shield':('shield','eye'),'hand':('hand','star'),'heal':('heart','sun'),'eye':('eye','star'),'dash':('foot','wind'),'dodge':('shield','foot'),'disengage':('foot','wing'),'stand':('foot','sun'),'shortrest':('moon','heart'),'longrest':('moon','clock'),'secondwind':('heart','wind'),'actionsurge':('sword','bolt'),'rage':('mask','flame'),'layonhands':('hand','heart'),'bardicinspiration':('mouth','star'),'ki':('rune','hand'),'channeldivinity':('sun','shield'),'wildshape':('paw','butterfly'),'sneakattack':('sword','mask')}
for name,(m,second) in actions.items():
 file='actions/'+name+'.svg';(OUT/file).write_text(icon(name,m,('#ead7a1','#8b6c3c'),second,kind='action'));manifest['actions'][name]={'path':'res://assets/icons/'+file}
classes={'Fighter':('sword','shield'),'Wizard':('book','wand'),'Rogue':('sword','mask'),'Cleric':('sun','heart'),'Paladin':('shield','sun'),'Ranger':('arrow','leaf'),'Druid':('tree','paw'),'Barbarian':('mask','sword'),'Bard':('mouth','book'),'Monk':('hand','rune'),'Sorcerer':('hand','flame'),'Warlock':('eye','tentacle')}
for name,(m,second) in classes.items():
 file='classes/'+key(name)+'.svg';(OUT/file).write_text(icon(name,m,('#e8d9b6','#5a817b'),second,kind='class'));manifest['classes'][key(name)]={'path':'res://assets/icons/'+file}
creatures={'bite':('hound','skull'),'claw':('hand','sword'),'talon':('bird','sword'),'slam':('hand','meteor'),'tail':('tentacle','sword'),'sting':('insect','flask'),'gore':('hound','arrow'),'tentacle':('tentacle','eye'),'breath':('hound','flame'),'fist':('hand','star'),'rock':('mountain','meteor'),'horn':('hound','sword'),'constrict':('rope','hound'),'beak':('bird','arrow'),'pseudopod':('tentacle','flask'),'web':('web','spider')}
for name,(m,second) in creatures.items():
 file='creatures/'+name+'.svg';(OUT/file).write_text(icon(name,m,('#ecbc98','#88535b'),second,kind='creature'));manifest['creatures'][name]={'path':'res://assets/icons/'+file}
(OUT/'catalog.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Ornate nine-slice metal frames: perimeter lighting, inset grooves and carved corners.
for name in ['panel','button','hover','pressed','selected','disabled','input','primary','tooltip','focus']:
 panel=name in ['panel','tooltip'];w,h=(256,160) if panel else (128,72);pad=7 if panel else 5
 top={'panel':'#292727','button':'#423c32','hover':'#61523a','pressed':'#221e1a','selected':'#54452f','disabled':'#282828','input':'#101719','primary':'#856b3c','tooltip':'#302b22','focus':'#1e2224'}[name]
 low={'panel':'#101518','button':'#222725','hover':'#2d332c','pressed':'#292d25','selected':'#272c25','disabled':'#1b2020','input':'#1f2727','primary':'#3f3829','tooltip':'#151b1c','focus':'#222725'}[name]
 bright='#e7c982' if name in ['hover','selected','primary','focus'] else '#a78c58' if name!='disabled' else '#59594e'
 d=f'M{pad+7} {pad}H{w-pad-7}L{w-pad} {pad+7}V{h-pad-7}L{w-pad-7} {h-pad}H{pad+7}L{pad} {h-pad-7}V{pad+7}Z'
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}"><defs><linearGradient id="surface" x2="0" y2="1"><stop stop-color="{top}"/><stop offset=".4" stop-color="{low}"/><stop offset="1" stop-color="#101719"/></linearGradient><linearGradient id="metal" x2=".3" y2="1"><stop stop-color="#f1d89d"/><stop offset=".17" stop-color="{bright}"/><stop offset=".46" stop-color="#675332"/><stop offset=".8" stop-color="#9e8050"/><stop offset="1" stop-color="#392f24"/></linearGradient></defs>'
 svg+=f'<path d="{d}" transform="translate(0 3)" fill="#06090c" stroke="#05080a" stroke-width="6"/><path d="{d}" fill="url(#surface)" stroke="url(#metal)" stroke-width="2.2"/>'
 svg+=f'<path d="M{pad+9} {pad+4}H{w-pad-9}M{pad+4} {pad+10}V{h-pad-10}" fill="none" stroke="{bright}" stroke-opacity=".38" stroke-width="1"/>'
 svg+=f'<path d="M{pad+10} {h-pad-4}H{w-pad-10}M{w-pad-4} {pad+10}V{h-pad-10}" fill="none" stroke="#05080b" stroke-width="2"/>'
 if panel:
  for x,y,sx,sy in [(12,12,1,1),(w-12,12,-1,1),(12,h-12,1,-1),(w-12,h-12,-1,-1)]:
   svg+=f'<g transform="translate({x} {y}) scale({sx} {sy})"><path d="M0 24V8Q0 0 8 0H24M5 19V9Q5 5 9 5H19M3 3L10 3L3 10Z" fill="none" stroke="{bright}" stroke-width="1"/><path d="M0 0L4 -3L8 0L4 3Z" fill="{bright}"/></g>'
  rng=random.Random(13)
  for _ in range(160):svg+=f'<circle cx="{rng.randint(20,w-20)}" cy="{rng.randint(20,h-20)}" r=".55" fill="#d9ba79" opacity=".05"/>'
 else:svg+=f'<path d="M{w/2-9} {pad+3}H{w/2+9}" fill="none" stroke="{bright}" stroke-opacity=".6"/>'
 svg+='</svg>';(ROOT/'ui'/f'{name}.svg').write_text(svg)
print('Created',len(manifest['spells']),'spell,',len(weapons),'weapon,',sum(len(v) for k,v in manifest.items() if k not in ['spells','weapons']),'action/class/creature illustrations and 10 gilded materials.')

for kind,top,mid,low in [('hp','#e4b49b','#a0443e','#3f2529'),('resource','#d0ebc0','#669d79','#264b3e')]:
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="16"><defs><linearGradient id="g" x2="0" y2="1"><stop stop-color="{top}"/><stop offset=".25" stop-color="{mid}"/><stop offset="1" stop-color="{low}"/></linearGradient></defs><rect x="1" y="1" width="126" height="14" rx="2" fill="url(#g)"/><path d="M3 2H125" stroke="{top}" stroke-opacity=".7"/></svg>'
 (ROOT/'ui'/f'{kind}.svg').write_text(svg)
