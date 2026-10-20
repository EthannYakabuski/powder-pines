"""Reproducible store artwork. Python 3 + Pillow only; no network or AI imagery.

When delivered in a game's marketing directory, run generate_assets.py there.
Brand artwork is illustrative, never labelled as a gameplay screenshot.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# External source locations are optional authoring inputs, never a private-PC default.
# A delivered per-game generator rebuilds from its own source_art directory.
SOURCE_ROOT: Path | None = None
STAGING_ROOT: Path | None = None
APPS: Path | None = None
SCALE = 3

BRANDS = {
    "pixel-safari-sanctuary": {
        "title": "Pixel Safari Sanctuary", "display": ["PIXEL SAFARI", "SANCTUARY"],
        "kind": "safari", "short": "Catch curious creatures, grow a cozy sanctuary, and discover rare family trees.",
        "palette": {"ink": "#183F39", "paper": "#F6F1DF", "primary": "#78A75C", "light": "#B8DCC3", "gold": "#F3C86A", "accent": "#E48B73"},
        "strap": "A little sanctuary. A world of curious creatures.",
        "feature_chips": ["EXPLORE", "CARE", "DISCOVER"],
        "achievements": "first_friend collection_10 collection_25 collection_50 collection_100 collection_200 first_safari safari_5 safari_25 safari_100 rare_keeper endangered_keeper extinct_revival first_breed breeder_10 breeder_25 income_500 income_10000 income_100000 level_5 level_10 level_20 seven_days".split(),
        "leaderboards": "collection player_level safari_captures total_income breeding_master".split(),
        "cards": [
            ["One more curious face", "Take a short safari and bring a new companion home. Every rarity has a place in your collection."],
            ["A sanctuary that grows with you", "Improve your enclosures, collect income, and make room for a thriving creature community."],
            ["Discover the family tree", "Pair specific parents to uncover creatures you cannot find on an ordinary outing."],
        ],
        "category": "GAME_SIMULATION", "tags": ["Casual", "Simulation", "Collecting", "Single player", "Offline"],
    },
    "powder-pines": {
        "title": "Powder Pines", "display": ["POWDER", "PINES"], "kind": "ski",
        "short": "Grow a cozy ski resort, open new runs, and carve a few turns of your own.",
        "palette": {"ink": "#183B54", "paper": "#F6FCFF", "primary": "#40A99C", "light": "#D9F0F4", "gold": "#EFBC63", "accent": "#F58467"},
        "strap": "Build your mountain. Find your perfect line.",
        "feature_chips": ["BUILD", "UNWIND", "SKI"],
        "achievements": "first_tracks run_builder backcountry full_mountain chalet_host dream_chalet team_spirit growing_team first_slalom clean_lines slope_regular winter_wealth alpine_tycoon season_two season_three mountain_legend seven_days quest_keeper level_five level_ten".split(),
        "leaderboards": "lifetime_revenue best_slalom player_level ski_runs".split(),
        "cards": [
            ["Your mountain, both sides", "Open pistes across the front and back of the hill and watch your little resort come to life."],
            ["A cozy management rhythm", "Improve the chalet, grow your team, and return to income earned while you were away."],
            ["Take a run yourself", "Trade your manager's desk for a short slalom and chase a cleaner line through the gates."],
        ],
        "category": "GAME_SIMULATION", "tags": ["Idle", "Simulation", "Skiing", "Single player", "Offline"],
    },
    "open-road-ramble": {
        "title": "Open Road Ramble", "display": ["OPEN ROAD", "RAMBLE"], "kind": "road",
        "short": "A relaxed endless drive: watch the scenery, spot rare cars, and stop for fuel.",
        "palette": {"ink": "#183A3F", "paper": "#F5F0DF", "primary": "#94D3B0", "light": "#D8E8CD", "gold": "#E9C86B", "accent": "#DF794D"},
        "strap": "No hurry. Just the next stretch of road.",
        "feature_chips": ["DRIVE", "NOTICE", "UNWIND"],
        "achievements": "first_mile scenic_5k long_weekend first_pass traffic_friend rare_spotter rare_collector first_refuel station_regular helping_hand daily_complete quest_trio level_5 level_10 road_kit four_seasons".split(),
        "leaderboards": "distance_total passing_total refuels_total player_level".split(),
        "cards": [
            ["The journey is the point", "Settle into an endless drive through changing scenery and a gentle day-night rhythm."],
            ["A friendly road", "Pull in for fuel, spot unusual vehicles, and accept a helping hand if your tank runs dry."],
            ["A travel notebook of your own", "Complete small daily goals, build your rare-car journal, and make the journey yours."],
        ],
        "category": "GAME_CASUAL", "tags": ["Casual", "Driving", "Relaxing", "Single player", "Offline"],
    },
}

LONG = {
    "safari": """Make a home for the wonderfully unusual.

Pixel Safari Sanctuary is a cozy creature-collecting game about short expeditions and the little sanctuary waiting when you return. Take your lures into the wild, time a capture, and bring your newest companion back to an enclosure of its own.

Build your collection across common, uncommon, rare, endangered, and extinct rarity tiers. Improve your pens, collect their income, and earn player experience as your sanctuary grows. Away for a while? Local progress and capped offline earnings keep the rhythm gentle.

Some discoveries begin at home. Explore a breeding tree with specific parent pairings and unlock creatures that an ordinary safari cannot reveal. A seven-day login reward cycle gives you another small reason to check in.

Choose a quick outing or spend a quiet moment with your collection. Your progress saves locally, and the core game remains playable offline.

The Android edition supports optional rewarded ads and ads at natural breaks. Online achievements and leaderboards depend on Google Play Games sign-in and configuration. The Web edition keeps local play available with graceful fallbacks for Android-only services.
""",
    "ski": """A small chalet. A whole mountain of possibilities.

Welcome to Powder Pines, a cozy idle ski resort where you decide which run opens next. Expand across the front and back of the hill, watch tiny skiers find their way down the pistes, and turn a humble mountain stop into a lively winter retreat.

Spend your earnings on new runs, chalet improvements, staff, and ticketing upgrades. The resort can earn a capped amount while you are away, so returning feels like opening the curtains on a fresh snow day.

When you want a change of pace, go skiing yourself. Take a short slalom run, thread the gates, and bring bonus rewards back to the village. Advance through seasons, complete small daily goals, and grow your player level along the way.

Your resort progress saves locally and the core game works offline. Take it at your own pace: build, watch, ski, and return when you feel like another turn.

The Android edition supports optional rewarded ads and ads between completed activities. Online achievements and leaderboards depend on Google Play Games sign-in and configuration. Android-only services gracefully fall back in the Web edition.
""",
    "road": """You do not have to win the road. Just enjoy it.

Open Road Ramble is a relaxed endless driving game made for the small pleasures of a journey: a new stretch of scenery, a rare car in the next lane, or a quiet stop for fuel.

Steer and slow down as you settle into the rhythm of the road. Pass traffic, keep an eye on the tank, and pull into a station when it is time for a break. If you run out of gas, a friendly driver will help you reach the nearest station so the trip can continue.

Fill a vehicle journal with unusual finds, personalize your car in the garage, and build your player level over time. Daily goals give a little direction when you want it, with targets for distance, passing cars, and refueling.

Changing landscapes and a day-night cycle make each drive feel like another page in a travel notebook. Your progress is saved locally, and the core journey works offline.

The Android edition supports optional rewarded ads and ads at between-trip transitions. Online achievements and leaderboards depend on Google Play Games sign-in and configuration. The Web edition keeps local play available without Android-only services.
""",
}

def font(size: int, bold: bool = False):
    candidates = [Path(r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf"), Path(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf")]
    for p in candidates:
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default(size=size)

def text_fit(draw, text, max_width, start, bold=True):
    size = start
    while draw.textbbox((0, 0), text, font=font(size, bold))[2] > max_width and size > 12:
        size -= 1
    return font(size, bold)

def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(tuple(int(v) for v in box), radius=int(radius), fill=fill, outline=outline, width=width)

def star_points(cx, cy, outer, inner, n=5):
    return [(cx + (outer if i % 2 == 0 else inner) * math.cos(-math.pi / 2 + i * math.pi / n), cy + (outer if i % 2 == 0 else inner) * math.sin(-math.pi / 2 + i * math.pi / n)) for i in range(n * 2)]

def symbol(draw, kind, box, color, accent):
    x0, y0, x1, y1 = box
    w, h = x1-x0, y1-y0
    def p(x, y): return (int(x0+x*w), int(y0+y*h))
    stroke = max(3, int(w*.055))
    if kind in ("collection", "friend"):
        draw.ellipse((*p(.12,.18),*p(.88,.84)), fill=color)
        draw.polygon([p(.13,.37),p(.03,.03),p(.4,.22)], fill=color)
        draw.polygon([p(.6,.22),p(.97,.03),p(.87,.37)], fill=color)
        draw.ellipse((*p(.29,.39),*p(.4,.54)),fill=accent)
        draw.ellipse((*p(.6,.39),*p(.71,.54)),fill=accent)
        draw.arc((*p(.3,.44),*p(.7,.71)),0,180,fill=accent,width=stroke)
    elif kind in ("safari", "compass"):
        draw.ellipse((*p(.12,.12),*p(.88,.88)),outline=color,width=stroke)
        draw.polygon([p(.7,.23),p(.55,.55),p(.3,.77),p(.45,.45)],fill=color)
        draw.ellipse((*p(.44,.44),*p(.56,.56)),fill=accent)
    elif kind == "breed":
        for t in range(0,8):
            yy=.12+t*.105
            xx=.28+.15*math.sin(t*math.pi/3)
            draw.line([p(xx,yy),p(1-xx,yy)], fill=color, width=stroke)
            draw.ellipse((*p(xx-.035,yy-.035),*p(xx+.035,yy+.035)),fill=color)
            draw.ellipse((*p(1-xx-.035,yy-.035),*p(1-xx+.035,yy+.035)),fill=color)
    elif kind == "coin":
        draw.ellipse((*p(.15,.15),*p(.85,.85)),fill=color)
        draw.ellipse((*p(.25,.25),*p(.75,.75)),outline=accent,width=stroke)
        draw.line([p(.5,.32),p(.5,.68)],fill=accent,width=stroke)
    elif kind == "mountain":
        draw.polygon([p(.04,.84),p(.4,.12),p(.58,.42),p(.72,.25),p(.97,.84)],fill=color)
        draw.polygon([p(.29,.35),p(.4,.12),p(.53,.35),p(.45,.31),p(.39,.39),p(.35,.31)],fill=accent)
    elif kind == "chalet":
        rounded(draw,(*p(.21,.39),*p(.79,.86)),w*.03,color)
        draw.polygon([p(.05,.44),p(.5,.08),p(.95,.44)],fill=color)
        rounded(draw,(*p(.43,.6),*p(.58,.86)),w*.01,accent)
        rounded(draw,(*p(.28,.49),*p(.39,.6)),w*.01,accent)
        rounded(draw,(*p(.61,.49),*p(.72,.6)),w*.01,accent)
    elif kind == "staff":
        for xx,yy in ((.5,.2),(.23,.34),(.77,.34)):
            draw.ellipse((*p(xx-.12,yy-.1),*p(xx+.12,yy+.14)),fill=color)
            rounded(draw,(*p(xx-.17,yy+.18),*p(xx+.17,yy+.52)),w*.06,color)
    elif kind == "flag":
        draw.line([p(.28,.12),p(.28,.9)],fill=color,width=stroke)
        draw.polygon([p(.31,.13),p(.84,.21),p(.68,.39),p(.83,.56),p(.31,.49)],fill=color)
    elif kind == "car":
        rounded(draw,(*p(.21,.12),*p(.79,.88)),w*.09,color)
        rounded(draw,(*p(.29,.29),*p(.71,.53)),w*.04,accent)
        rounded(draw,(*p(.29,.65),*p(.71,.76)),w*.03,accent)
        draw.rectangle((*p(.15,.28),*p(.23,.46)),fill=color)
        draw.rectangle((*p(.77,.28),*p(.85,.46)),fill=color)
    elif kind == "road":
        draw.polygon([p(.08,.92),p(.38,.08),p(.62,.08),p(.92,.92)],fill=color)
        for a,b in ((.18,.3),(.42,.56),(.69,.85)):
            draw.line([p(.5,a),p(.5,b)],fill=accent,width=stroke)
    elif kind == "fuel":
        rounded(draw,(*p(.19,.13),*p(.67,.88)),w*.05,color)
        rounded(draw,(*p(.27,.22),*p(.59,.48)),w*.03,accent)
        draw.line([p(.67,.35),p(.82,.47),p(.82,.77),p(.94,.77)],fill=color,width=stroke)
        draw.line([p(.79,.15),p(.94,.31),p(.88,.43)],fill=color,width=stroke)
    elif kind == "calendar":
        rounded(draw,(*p(.12,.23),*p(.88,.88)),w*.06,color)
        draw.line([p(.14,.4),p(.86,.4)],fill=accent,width=stroke)
        for xx in (.31,.69): draw.line([p(xx,.13),p(xx,.33)],fill=color,width=stroke)
        draw.polygon(star_points(*p(.5,.63),w*.16,w*.07),fill=accent)
    elif kind == "trophy":
        rounded(draw,(*p(.28,.13),*p(.72,.58)),w*.07,color)
        draw.arc((*p(.07,.18),*p(.4,.6)),60,280,fill=color,width=stroke)
        draw.arc((*p(.6,.18),*p(.93,.6)),260,480,fill=color,width=stroke)
        draw.line([p(.5,.51),p(.5,.82)],fill=color,width=stroke)
        rounded(draw,(*p(.28,.8),*p(.72,.89)),w*.025,color)
    else:
        draw.polygon(star_points(*p(.5,.5),w*.42,w*.2),fill=color)

def key_symbol(key, kind, is_board=False):
    if is_board: return "trophy"
    if any(w in key for w in ("income", "wealth", "tycoon", "revenue")): return "coin"
    if any(w in key for w in ("breed", "revival")): return "breed"
    if any(w in key for w in ("safari", "rare_spot")): return "safari"
    if any(w in key for w in ("collection", "friend", "keeper")) and kind=="safari": return "collection"
    if "chalet" in key: return "chalet"
    if any(w in key for w in ("team", "staff")): return "staff"
    if any(w in key for w in ("refuel", "station", "helping")): return "fuel"
    if any(w in key for w in ("car", "pass", "traffic", "road_kit")): return "car"
    if any(w in key for w in ("mile", "scenic", "weekend", "seasons")) and kind=="road": return "road"
    if any(w in key for w in ("seven", "daily", "quest")): return "calendar"
    if any(w in key for w in ("slalom", "lines")): return "flag"
    if any(w in key for w in ("run", "mountain", "tracks", "backcountry", "season")): return "mountain"
    return "star"

def numbered(key):
    bits=key.split('_')
    if bits[-1].isdigit():
        num=int(bits[-1]); return f"{num//1000}K" if num>=1000 else str(num)
    for word,label in (("five","5"),("ten","10"),("two","II"),("three","III")):
        if bits[-1]==word:return label
    return ""

def save_small(im, path):
    im.convert('RGB').save(path, optimize=True)

def fit_pixel_art(im, width, height):
    factor=min(width/im.width,height/im.height)
    return im.resize((max(1,round(im.width*factor)),max(1,round(im.height*factor))),Image.Resampling.NEAREST)

def make_icon(out, b):
    p=b['palette']; s=512*SCALE
    im=Image.new('RGB',(s,s),p['ink']); d=ImageDraw.Draw(im)
    # Full square artwork; the store/platform applies its own display mask.
    d.ellipse((int(-s*.2),int(s*.55),int(s*.65),int(s*1.3)),fill=p['primary'])
    d.ellipse((int(s*.65),int(-s*.2),int(s*1.3),int(s*.5)),fill=p['primary'])
    if b['kind']=='safari':
        d.ellipse((s*.16,s*.16,s*.84,s*.84),fill=p['paper'])
        sprite=out/'source_art'/'hero_creature.png'
        if sprite.exists():
            cr=fit_pixel_art(Image.open(sprite).convert('RGBA'),int(s*.67),int(s*.67))
            im.paste(cr,(int((s-cr.width)/2),int((s-cr.height)/2+s*.025)),cr)
        else:symbol(d,'collection',(s*.23,s*.25,s*.77,s*.79),p['ink'],p['gold'])
        d.polygon(star_points(s*.78,s*.24,s*.11,s*.05),fill=p['gold'])
    elif b['kind']=='ski':
        symbol(d,'mountain',(s*.08,s*.12,s*.92,s*.87),p['paper'],p['light'])
        d.line([(s*.39,s*.42),(s*.58,s*.62),(s*.43,s*.87)],fill=p['accent'],width=int(s*.055),joint='curve')
        for xx,yy in ((.18,.72),(.81,.72)):
            d.polygon([(s*xx,s*(yy-.21)),(s*(xx-.08),s*yy),(s*(xx+.08),s*yy)],fill=p['primary'])
    else:
        d.ellipse((s*.64,s*.1,s*.87,s*.33),fill=p['gold'])
        d.polygon([(0,s*.56),(s*.28,s*.35),(s*.53,s*.55),(s*.75,s*.38),(s,s*.6),(s,s),(0,s)],fill=p['primary'])
        d.polygon([(s*.17,s),(s*.43,s*.46),(s*.57,s*.46),(s*.86,s)],fill=p['paper'])
        d.line([(s*.5,s*.54),(s*.5,s*.66)],fill=p['ink'],width=int(s*.025))
        symbol(d,'car',(s*.34,s*.59,s*.66,s*.98),p['accent'],p['ink'])
    im=im.resize((512,512),Image.Resampling.LANCZOS)
    save_small(im,out/'app-icon-512.png')
    # Small launcher preview remains a true reduced rendering of the same source.
    save_small(im.resize((192,192),Image.Resampling.LANCZOS),out/'app-icon-192.png')

def make_badge(out,b,key,is_board=False):
    p=b['palette']; s=512*SCALE
    im=Image.new('RGB',(s,s),p['paper']); d=ImageDraw.Draw(im)
    d.ellipse((s*.06,s*.06,s*.94,s*.94),fill=p['ink'])
    d.ellipse((s*.105,s*.105,s*.895,s*.895),outline=p['gold'],width=int(s*.025))
    symbol(d,key_symbol(key,b['kind'],is_board),(s*.27,s*.24,s*.73,s*.7),p['light'] if is_board else p['gold'],p['ink'])
    board_labels={'collection':'COL','player_level':'LVL','safari_captures':'CAP','total_income':'INC','breeding_master':'DNA','lifetime_revenue':'REV','best_slalom':'SKI','ski_runs':'RUN','distance_total':'KM','passing_total':'PASS','refuels_total':'FUEL'}
    n=board_labels.get(key,key[:3].upper()) if is_board else numbered(key)
    if n:
        f=font(int(s*.12),True); box=d.textbbox((0,0),n,font=f)
        d.text(((s-(box[2]-box[0]))/2,s*.7),n,font=f,fill=p['paper'])
    else:
        for xx in (.44,.5,.56): d.ellipse((s*(xx-.011),s*.77,s*(xx+.011),s*.792),fill=p['paper'])
    folder=out/('leaderboards' if is_board else 'achievements');folder.mkdir(exist_ok=True)
    save_small(im.resize((512,512),Image.Resampling.LANCZOS),folder/(key+'.png'))

def make_feature(out,b):
    p=b['palette']; sc=2; w,h=1024*sc,500*sc
    im=Image.new('RGB',(w,h),p['paper']);d=ImageDraw.Draw(im)
    # Decorative brand illustration on the right, not a mock gameplay UI.
    d.ellipse((w*.55,-h*.35,w*1.14,h*1.28),fill=p['light'])
    if b['kind']=='safari':
        for xx,yy,rr in ((.65,.3,.13),(.91,.64,.15),(.72,.86,.12)):
            d.ellipse((w*(xx-rr),h*(yy-rr*2),w*(xx+rr),h*(yy+rr*2)),fill=p['primary'])
        for i,(xx,yy,sz) in enumerate(((.72,.52,.3),(.88,.34,.2),(.89,.79,.2))):
            fn=out/'source_art'/('hero_creature.png' if i==0 else f'companion_{i}.png')
            if fn.exists():
                cr=fit_pixel_art(Image.open(fn).convert('RGBA'),int(w*sz),int(h*.65))
                im.paste(cr,(int(w*xx-cr.width/2),int(h*yy-cr.height/2)),cr)
        for xx,yy in ((.64,.15),(.93,.15),(.59,.78)):
            d.polygon(star_points(w*xx,h*yy,w*.016,w*.007),fill=p['gold'])
    elif b['kind']=='ski':
        d.polygon([(w*.56,h*.8),(w*.75,h*.1),(w*.96,h*.8)],fill=p['ink'])
        d.polygon([(w*.675,h*.37),(w*.75,h*.1),(w*.825,h*.37),(w*.78,h*.32),(w*.735,h*.4),(w*.71,h*.3)],fill=p['paper'])
        d.polygon([(w*.72,h*.9),(w*.91,h*.36),(w*1.08,h*.9)],fill=p['primary'])
        d.line([(w*.75,h*.4),(w*.73,h*.53),(w*.81,h*.62),(w*.76,h*.78)],fill=p['accent'],width=12*sc,joint='curve')
        for xx,yy in ((.61,.8),(.92,.84),(.96,.64)):
            d.polygon([(w*xx,h*(yy-.16)),(w*(xx-.035),h*yy),(w*(xx+.035),h*yy)],fill=p['ink'])
        symbol(d,'chalet',(w*.57,h*.61,w*.72,h*.91),p['accent'],p['paper'])
    else:
        d.ellipse((w*.82,h*.12,w*.94,h*.36),fill=p['gold'])
        d.polygon([(w*.55,h*.62),(w*.73,h*.28),(w*.92,h*.62),(w,h*.4),(w,h),(w*.55,h)],fill=p['primary'])
        d.polygon([(w*.59,h),(w*.76,h*.4),(w*.83,h*.4),(w*.99,h)],fill=p['ink'])
        for aa,bb in ((.48,.57),(.66,.78),(.86,.98)):
            d.line([(w*.795,h*aa),(w*.795,h*bb)],fill=p['paper'],width=7*sc)
        symbol(d,'car',(w*.82,h*.61,w*.93,h*.94),p['accent'],p['paper'])
    d.text((48*sc,42*sc),"A LITTLE GAME FOR YOUR EVERYDAY",font=font(13*sc,True),fill=p['ink'])
    top=115*sc
    for i,line in enumerate(b['display']):
        fs=70*sc if i==0 else 61*sc
        if b['kind']=='safari' and i==1: fs=35*sc
        f=text_fit(d,line,530*sc,fs)
        d.text((46*sc,top),line,font=f,fill=p['ink'])
        top += (78 if i==0 else 65)*sc
    # Keep the strap intentionally short so its promised feature is readable.
    strap=b['strap']
    f=text_fit(d,strap,510*sc,20*sc,False)
    d.text((49*sc,316*sc),strap,font=f,fill=p['ink'])
    xx=49*sc
    for chip in b['feature_chips']:
        f=font(13*sc,True);cw=d.textbbox((0,0),chip,font=f)[2]+28*sc
        rounded(d,(xx,378*sc,xx+cw,416*sc),19*sc,p['ink'])
        d.text((xx+14*sc,386*sc),chip,font=f,fill=p['paper']);xx+=cw+10*sc
    save_small(im.resize((1024,500),Image.Resampling.LANCZOS),out/'feature-graphic-1024x500.png')

def copy_sources(out,b):
    art=out/'source_art';art.mkdir(exist_ok=True)
    if b['kind']=='safari':
        source=SOURCE_ROOT/'KennyMonsters_spritesheets' if SOURCE_ROOT else None
        names=['acorn_king.png','amber_antlers.png','amethyst_earl.png']
        for i,name in enumerate(names):
            target=art/('hero_creature.png' if i==0 else f'companion_{i}.png')
            if not target.exists() and source and (source/name).exists():
                sheet=Image.open(source/name).convert('RGBA')
                frame=sheet.crop((0,0,sheet.height,sheet.height));bbox=frame.getbbox()
                if bbox:frame=frame.crop(bbox)
                frame.save(target,optimize=True)
        (art/'PROVENANCE.txt').write_text('Creature artwork: Kenney Creature Mixer output, supplied by the project owner in KennyMonsters_spritesheets.\nSource: https://kenney.itch.io/creature-mixer\nCommercial-use rights were reviewed by the owner before this workflow began.\nMarketing extracts use the first complete 192x192 animation frame, with only transparent margins removed.\nOriginal sprite authorship remains with its credited source.\n',encoding='utf-8')
    # Preserve notices for any source kit represented in these packages.
    packs=['kenney_tiny-ski'] if b['kind']=='ski' else ['kenney_car-kit'] if b['kind']=='road' else []
    for pack in packs:
        for name in ('License.txt','license.txt'):
            src=SOURCE_ROOT/'AllOfKennysAssets'/pack/name if SOURCE_ROOT else None
            if src and src.exists():
                shutil.copyfile(src,art/(pack+'-License.txt'));break

def catalog_entries(out,b):
    entries={group:[{'key':key,'name':key.replace('_',' ').title()} for key in b[group]] for group in ('achievements','leaderboards')}
    src=out.parent/'game'/'catalog.json'
    if src.exists():
        obj=json.loads(src.read_text(encoding='utf-8-sig'))
        for group in entries:
            raw=obj.get(group,[])
            if isinstance(raw,dict): raw=[dict(v,key=k) if isinstance(v,dict) else {'key':k,'name':str(v)} for k,v in raw.items()]
            actual=[]
            for item in raw:
                if isinstance(item,str):actual.append({'key':item,'name':item.replace('_',' ').title()});continue
                key=item.get('key',item.get('id',item.get('symbol','')))
                if key:actual.append({'key':key,'name':item.get('name',item.get('title',key.replace('_',' ').title())),'description':item.get('description','')})
            if actual:entries[group]=actual
    return entries,src.exists()

def write_text_package(out,b,entries,catalog_present):
    assert len(b['short'])<=80,(b['title'],len(b['short']))
    payload={
        'title':b['title'],'short_description':b['short'],'long_description':LONG[b['kind']].strip(),
        'category':b['category'],'suggested_tags':b['tags'],'orientation':'portrait',
        'developer':'EthannYakabuski','target_platforms':['Android','Web where feasible'],
        'feature_graphic':'feature-graphic-1024x500.png','app_icon':'app-icon-512.png',
        'achievement_icons':[{**e,'file':'achievements/'+e['key']+'.png'} for e in entries['achievements']],
        'leaderboard_icons':[{**e,'file':'leaderboards/'+e['key']+'.png'} for e in entries['leaderboards']],
        'copy_validation':'Draft aligned to the game brief; confirm against actual implemented build before store submission.',
        'external_services':'Google Play Games IDs/backend and production AdMob account configuration/final tests are supplied by the owner. First-pass ads use test IDs.',
    }
    (out/'store-listing.json').write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    listing=f"{b['title']}\n\nSHORT DESCRIPTION ({len(b['short'])}/80 characters)\n{b['short']}\n\nLONG DESCRIPTION\n{LONG[b['kind']].strip()}\n\nCATEGORY\n{b['category']}\n\nSUGGESTED TAGS\n{', '.join(b['tags'])}\n\nPUBLICATION NOTE\nThis is store copy for the implemented candidate, not a claim of publication or production-service verification. Check feature claims against the final build before uploading. The owner completes backend configuration, final testing, privacy/Data safety declarations, audience/content-rating questionnaires, support/privacy URLs, and Google Play publication.\n"
    (out/'store-listing.txt').write_text(listing,encoding='utf-8')
    webpage=[b['title'],b['strap'],'',LONG[b['kind']].split('\n\n')[1],'','THREE SELLING CARDS']
    for title,body in b['cards']:webpage.extend([title,body,''])
    webpage.extend(['TECHNICAL INFORMATION','Made with Godot 4.5.1 Compatibility. Portrait Android is primary; a Web build is provided where feasible. Local saves support offline core play. Android services have graceful Web fallbacks. Original code is Apache-2.0; source-asset/plugin notices are preserved. Google Play Games and production ads require the owner\'s final configuration.','','FUTURE CONTENT IDEA (NOT IMPLEMENTED)',{'safari':'A seasonal wetland expedition with new family-tree branches and sanctuary decorations.','ski':'A summer mountain-bike season with a new activity and a distinct resort economy.','road':'A postcard road atlas with new landmark stops and optional route collections.'}[b['kind']]])
    (out/'webpage-copy.txt').write_text('\n'.join(webpage)+'\n',encoding='utf-8')
    shots=out/'screenshots';shots.mkdir(exist_ok=True)
    (shots/'CAPTURE-INSTRUCTIONS.txt').write_text('GAMEPLAY SCREENSHOTS - ACTUAL BUILD CAPTURE REQUIRED\n\nDo not fill this directory with illustrated or fabricated gameplay. Capture actual implemented game states after the app is runnable.\nPhone: portrait 1080x1920 target. Capture at least home/management, active play, and progression/collection states.\n7-inch tablet: portrait 1200x1920 target; capture actual layout at that viewport.\n10-inch tablet: portrait 1600x2560 target; capture actual layout at that viewport.\nUse the current Play Console upload requirements when preparing submission.\nGodot viewport captures are local-build evidence; identify the capture platform in capture-manifest.json and separately retain Android device/emulator captures when available. Do not label desktop/editor captures as phone hardware captures.\nThe project owner performs final device and store submission review.\n',encoding='utf-8')
    (out/'ASSET-SPECS.txt').write_text('APP ICON\napp-icon-512.png: 512x512 RGB PNG, full-square source artwork. Platform/store supplies display mask.\napp-icon-192.png: 192x192 RGB launcher preview.\n\nFEATURE GRAPHIC\nfeature-graphic-1024x500.png: 1024x500 RGB PNG. Original brand illustration; not a gameplay screenshot.\n\nACHIEVEMENTS AND LEADERBOARDS\nIndividual named 512x512 RGB PNGs under achievements/ and leaderboards/. Symbolic keys in store-listing.json must map to final console IDs.\n\nREBUILD\nRun python generate_assets.py from this marketing directory with Pillow installed in the existing environment. It reads brand.json and game/catalog.json when present; it does not use the network. source_art/ retains the small source extracts needed to regenerate the Pixel Safari artwork. Source fonts are read from the installed Windows font library for rendering and are not redistributed.\n\nLICENSING\nGenerated branding/code is part of the original Apache-2.0 project work. Supplied Kenney source art remains under its own provenance/notices. Preserve source_art notices and the root project notices.\n',encoding='utf-8')
    (out/'STORE-HANDOFF.txt').write_text(f'''STORE / WEBSITE HANDOFF - {b['title']}

PREPARED IN THIS PACKAGE
- App title, short description (verified <=80 characters), long description, category and suggested tags.
- Full-square 512x512 RGB app icon and 192x192 launcher preview.
- 1024x500 RGB feature graphic, explicitly original brand illustration.
- Individual 512x512 achievement and leaderboard icons, aligned to the symbolic game catalog.
- Website introduction, three selling cards, technical paragraph and one future-content concept.
- Source provenance/notices, asset dimensions/checksums and a repeatable offline generator.

ACTUAL GAME CAPTURES
Capture actual implemented home/management, active gameplay, and progress/collection states.
Suggested filenames: screenshots/phone-home.png, phone-play.png, phone-progress.png;
tablet-7-home.png, tablet-7-play.png; tablet-10-home.png, tablet-10-play.png.
Record source build/commit, platform, viewport, game state/fixture, file hash and visual review
in screenshots/capture-manifest.json. Do not present editor/Web captures as Android hardware captures.
Artwork in feature-graphic-1024x500.png is not a substitute for these screenshots.

OWNER'S FINAL PLAY CONSOLE / BACKEND ITEMS
- Final public support contact and privacy-policy URL.
- Final package/version/release artifacts and signing setup supplied by the build/release handoff.
- Real Play Games app/achievement/leaderboard IDs and production AdMob IDs/account configuration.
- Final audience, content rating, ads declaration, privacy/Data safety answers and SDK disclosures
  based on the final app/dependencies and the owner's actual configuration; do not infer "no data"
  merely from the game's local-save support.
- Final real-service/device testing and Google Play submission/publication by the owner.

These are the agreed final human publication/configuration responsibilities, not a new prototype
approval gate. No store listing has been submitted or published by this generator.
''',encoding='utf-8')
    manifest={
        'generated_at_utc':datetime.now(timezone.utc).isoformat(),'catalog_present':catalog_present,
        'catalog_source':'../game/catalog.json' if catalog_present else 'planned keys in brand.json; regenerate once catalog is present',
        'app_icon':'ready','feature_graphic':'ready_illustrative_brand_art','achievement_icons':len(entries['achievements']),'leaderboard_icons':len(entries['leaderboards']),
        'phone_screenshots':'captured_check_capture_manifest' if list(shots.glob('phone-*.png')) else 'pending_actual_build_capture',
        'tablet_7_screenshots':'captured_check_capture_manifest' if list(shots.glob('tablet-7-*.png')) else 'pending_actual_build_capture',
        'tablet_10_screenshots':'captured_check_capture_manifest' if list(shots.glob('tablet-10-*.png')) else 'pending_actual_build_capture',
        'production_services':'pending_owner_configuration_and_final_testing','gameplay_claims':'pending_core_agent_implementation_confirmation',
    }
    (out/'package-status.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    (out/'CHECKPOINT.txt').write_text(f"Marketing package checkpoint - {datetime.now(timezone.utc).isoformat()}\nApp: {b['title']}\nGenerated: app icons, feature graphic, achievement/leaderboard icons, store listing, website copy, source notices, repeatable generator.\nCatalog available: {catalog_present}\nPending: reconcile final catalog/implemented features; capture real phone/tablet game states and record capture provenance; owner final backend/store configuration.\nNext action: rerun generate_assets.py once catalog exists, then request actual captures from root.\n",encoding='utf-8')

def generate_game(out,b):
    out.mkdir(parents=True,exist_ok=True)
    copy_sources(out,b);make_icon(out,b);make_feature(out,b)
    entries,present=catalog_entries(out,b)
    for group in entries:
        for entry in entries[group]:make_badge(out,b,entry['key'],group=='leaderboards')
    write_text_package(out,b,entries,present)
    records=[]
    for f in sorted(out.rglob('*.png')):
        with Image.open(f) as im: dims=list(im.size);mode=im.mode
        records.append({'file':f.relative_to(out).as_posix(),'dimensions':dims,'mode':mode,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
    (out/'asset-manifest.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
    return {'game':b['title'],'assets':len(records),'achievements':len(entries['achievements']),'leaderboards':len(entries['leaderboards']),'catalog_present':present,'short_chars':len(b['short'])}

def asset_review(path):
    packs=SOURCE_ROOT/'AllOfKennysAssets'
    lines=['SUPPLIED ASSET REVIEW',f'UTC: {datetime.now(timezone.utc).isoformat()}','Scope: all supplied pack folders were inventoried, file formats/counts and available preview/sample images reviewed. This preserves the owner\'s prior commercial-use review rather than reopening it.','','PACK INVENTORY']
    previews=[]
    for pack in sorted(packs.iterdir()):
        if not pack.is_dir():continue
        files=[p for p in pack.rglob('*') if p.is_file()]
        formats=Counter(p.suffix.lower() or '[none]' for p in files)
        notice=[p.relative_to(pack).as_posix() for p in files if p.name.lower() in ('license.txt','license.md','copying','notice')]
        preview=next((p for p in files if p.name.lower()=='preview.png'),None)
        if preview:previews.append((pack.name,preview))
        lines.append(f"{pack.name}: {len(files)} files; {dict(sorted(formats.items()))}; notices={notice}; preview={'yes' if preview else 'no'}")
    monsters=SOURCE_ROOT/'KennyMonsters_spritesheets'
    monster_files=sorted(monsters.glob('*.png'))
    dims=Counter(Image.open(p).size for p in monster_files)
    lines.extend(['','CREATURE SHEETS',f'{len(monster_files)} PNG sheets, dimension counts: {dict(dims)}. Visual inspection confirms each 768x192 sheet is four complete 192x192 animation frames, not a 48px grid.','','FIRST THREE GAMES: ASSET CHOICES','Pixel Safari Sanctuary: supplied creature sheets provide the full collection art. Warm native UI, enclosure scenery and visual effects can be generated in code; no need to invent replacement creature artwork.','Powder Pines: tiny-ski provides piste, lift/gondola, trees, flags, chalet and skier pixels. Its individual 16px tiles and sample map support a coherent hill; use the supplied tile format rather than trying to flatten unrelated 3D models.','Open Road Ramble: car-kit provides low-poly vehicle models and a preview useful for vehicle references/garage art; tiny-town, nature and city kits provide related scenery. The core agent is building a deliberate flat roadway instead of using miscellaneous mismatched assets.','','OTHER AVAILABLE DIRECTIONS','Desert-shooter, mini-characters, crosshairs, impact sounds, smoke and particles support the seeded shooter briefs.','Tiny-farm/tiny-town, market and UI packs support management games. Pirate, train, watercraft and survival packs support later generated ideas.','Many city, car, foliage, furniture and nature packs are 3D (FBX/OBJ/GLB). Prefer their authored models for a true 3D project or carefully prepared sprites; they are not automatically interchangeable with the pixel tile packs.','Audio packs cover interface, digital, impact, RPG and casino-style feedback; preserve each used pack notice.','Game icons, medals, emotes, borders and input prompts can reduce redundant new-asset generation.','','MARKETING RULE','Feature graphics and app/achievement art are original brand illustrations made from code/native shapes and selected supplied creature art. Gameplay screenshots must be captured from actual implemented builds with platform/viewport provenance. Do not present brand illustrations as screenshots.'])
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return previews

def contact_sheet(previews,out):
    cw,ch=240,180;cols=6;rows=math.ceil(len(previews)/cols)
    im=Image.new('RGB',(cols*cw,rows*ch),'#F4F4F0');d=ImageDraw.Draw(im)
    for i,(name,p) in enumerate(previews):
        x,y=(i%cols)*cw,(i//cols)*ch
        img=Image.open(p).convert('RGB');img.thumbnail((cw-12,ch-36))
        im.paste(img,(x+(cw-img.width)//2,y+4))
        d.text((x+6,y+ch-29),name.replace('kenney_','')[:30],font=font(13,True),fill='#163A3A')
    im.save(out)

def main():
    global SOURCE_ROOT,STAGING_ROOT,APPS
    ap=argparse.ArgumentParser();ap.add_argument('--batch',action='store_true');ap.add_argument('--review',action='store_true');ap.add_argument('--contact-sheet');ap.add_argument('--source-root',type=Path);ap.add_argument('--staging-root',type=Path);ap.add_argument('--games',help='Comma-separated batch subset');args=ap.parse_args()
    SOURCE_ROOT=args.source_root.resolve() if args.source_root else None
    STAGING_ROOT=args.staging_root.resolve() if args.staging_root else None
    APPS=SOURCE_ROOT/'Apps' if SOURCE_ROOT else None
    if (args.batch or args.review) and SOURCE_ROOT is None:ap.error('--source-root is required for authoring batch/review mode')
    if args.batch:
        here=Path(__file__).read_text(encoding='utf-8')
        for slug,b in BRANDS.items():
            if args.games and slug not in args.games.split(','):continue
            out=APPS/slug/'marketing';out.mkdir(parents=True,exist_ok=True)
            (out/'brand.json').write_text(json.dumps(b,indent=2)+'\n',encoding='utf-8')
            (out/'generate_assets.py').write_text(here,encoding='utf-8')
            print(json.dumps(generate_game(out,b)))
    elif not args.review:
        out=Path(__file__).resolve().parent
        b=json.loads((out/'brand.json').read_text(encoding='utf-8'))
        print(json.dumps(generate_game(out,b)))
    if args.review:
        previews=asset_review(APPS/'_pipeline'/'asset-review.txt')
        if args.contact_sheet:contact_sheet(previews,Path(args.contact_sheet))
        print(json.dumps({'review_packs':len(previews),'review_path':str(APPS/'_pipeline'/'asset-review.txt')}))

if __name__=='__main__':main()
