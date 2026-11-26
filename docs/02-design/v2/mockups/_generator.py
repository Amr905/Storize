import json, os
OUT='/home/claude/canvas/project'
MARK={'light':'/_blob/ec3791afd1aee863a632f49d3415b9fd','dark':'/_blob/b4da049fea85c64994d64fa5681bf555'}
TOK=json.load(open('/home/claude/ds/project/tokens.json'))['color']['tokens']
def vars_for(th): return ';'.join(f'--{t["name"]}:{t["value"][th]}' for t in TOK)
# photo stand-ins: muted tones (not gradients)
PH=['#C98B6B','#7E8FB3','#8DB09A','#D4A55A','#A9789E','#6F9DA6','#B7836A','#93A07A','#C27C7C']

ICONS={
'search':'<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
'filter':'<path d="M4 7h16M7 12h10M10 17h4"/>',
'back':'<path d="M15 5l-7 7 7 7"/>',
'close':'<path d="M6 6l12 12M18 6L6 18"/>',
'more':'<circle cx="12" cy="5" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="12" cy="19" r="1.3"/>',
'library':'<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/>',
'people':'<circle cx="9" cy="9" r="3.5"/><path d="M3 19c.8-3.2 3.2-5 6-5s5.2 1.8 6 5"/><circle cx="17" cy="8" r="2.5"/><path d="M16 13.5c2.4.2 4.2 1.8 5 4.5"/>',
'activity':'<path d="M3 12h4l3-7 4 14 3-7h4"/>',
'settings':'<circle cx="12" cy="12" r="3"/><path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8"/>',
'plus':'<path d="M12 5v14M5 12h14"/>',
'check':'<path d="M5 12.5l4.5 4.5L19 7.5"/>',
'download':'<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
'play':'<path d="M8 5.5v13l11-6.5z" fill="currentColor"/>',
'stack':'<rect x="7" y="7" width="12" height="12" rx="2"/><path d="M5 15V7a2 2 0 0 1 2-2h8"/>',
'refresh':'<path d="M19 8a7.5 7.5 0 1 0 1 6"/><path d="M20 3.5V8h-4.5"/>',
'pause':'<path d="M9 6v12M15 6v12"/>',
'sun':'<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
'moon':'<path d="M19.5 14.5A7.5 7.5 0 0 1 9.5 4.5a7.5 7.5 0 1 0 10 10z"/>',
'phone':'<rect x="7" y="3" width="10" height="18" rx="2.5"/><path d="M11 18h2"/>',
'chevron':'<path d="M9 6l6 6-6 6"/>',
'share':'<path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 13v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5"/>',
'info':'<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>',
'trash':'<path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/>',
'shield':'<path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z"/>',
'bell':'<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5h4"/>',
'eye':'<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>',
'lock':'<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
'warn':'<path d="M12 4l9 16H3z"/><path d="M12 10v4.5M12 17.5h.01"/>',
'highlight':'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5l1.4 2.9 3.1.4-2.3 2.2.6 3.1-2.8-1.5-2.8 1.5.6-3.1-2.3-2.2 3.1-.4z"/>',
}
def ic(name,size=24,color='var(--ink)',sw=1.8):
    return f'<svg aria-hidden="true" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" style="flex:none;color:{color}">{ICONS[name]}</svg>'

def avatar(letter,col,size=40,ring=False):
    r=f'box-shadow:0 0 0 2px var(--surface),0 0 0 4px var(--brand);' if ring else ''
    return f'<div style="width:{size}px;height:{size}px;border-radius:999px;background:{col};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:600;font-size:{int(size*0.42)}px;flex:none;{r}">{letter}</div>'

def pill(text,kind):
    m={'active':('success','Active'),'paused':('neutral-status','Paused'),'warn':('warning','Needs re-login'),'waiting':('neutral-status','Waiting to look up'),'checking':('brand','Checking…'),'error':('error','Restricted')}
    tok,_=m[kind]
    return f'<span style="display:inline-flex;align-items:center;gap:6px;padding:3px 10px;border-radius:999px;background:var(--surface-container-high);color:var(--ink);font-size:12px;line-height:16px;font-weight:500;white-space:nowrap"><span style="width:8px;height:8px;border-radius:999px;background:var(--{tok})"></span>{text}</span>'

def chip(text,sel=False):
    if sel:
        return f'<button style="border:0;padding:7px 14px;border-radius:10px;background:var(--brand-container);color:var(--on-brand-container);font:500 13px/18px Roboto,sans-serif;display:inline-flex;align-items:center;gap:6px">{ic("check",16,"var(--on-brand-container)",2.2)}{text}</button>'
    return f'<button style="border:1px solid var(--outline-strong);padding:6px 13px;border-radius:10px;background:transparent;color:var(--ink);font:500 13px/18px Roboto,sans-serif">{text}</button>'

def thumb(i,w,h,new=False,video=None,carousel=None,check=None,hl=False):
    ring='box-shadow:0 0 0 2px var(--surface),0 0 0 4px var(--brand);' if new else ''
    badges=''
    if video: badges+=f'<span style="position:absolute;left:6px;bottom:6px;display:inline-flex;align-items:center;gap:3px;padding:2px 6px;border-radius:999px;background:var(--media-scrim);color:#fff;font-size:11px;font-weight:500">{ic("play",10,"#fff")}{video}</span>'
    if carousel: badges+=f'<span style="position:absolute;right:6px;top:6px;display:inline-flex;align-items:center;gap:3px;padding:2px 6px;border-radius:999px;background:var(--media-scrim);color:#fff;font-size:11px;font-weight:500">{ic("stack",11,"#fff",2)}{carousel}</span>'
    if hl: badges+=f'<span style="position:absolute;left:6px;top:6px;padding:2px 7px;border-radius:999px;background:var(--accent-container);color:var(--accent);font-size:11px;font-weight:600">Highlight</span>'
    if check is True: badges+=f'<span style="position:absolute;right:6px;bottom:6px;width:22px;height:22px;border-radius:999px;background:var(--brand);display:flex;align-items:center;justify-content:center">{ic("check",14,"var(--on-brand)",2.6)}</span>'
    elif check=='saved': badges+=f'<span style="position:absolute;right:6px;bottom:6px;width:22px;height:22px;border-radius:999px;background:var(--success);display:flex;align-items:center;justify-content:center">{ic("check",14,"#fff",2.6)}</span>'
    elif check is False: badges+='<span style="position:absolute;right:6px;bottom:6px;width:20px;height:20px;border-radius:999px;border:2px solid #fff;background:rgba(0,0,0,.2)"></span>'
    shape=f'<div style="position:absolute;left:22%;top:26%;width:56%;height:40%;border-radius:999px;background:rgba(255,255,255,.18)"></div>'
    return f'<div style="position:relative;width:{w}px;height:{h}px;border-radius:12px;background:{PH[i%len(PH)]};overflow:hidden;flex:none;{ring}">{shape}{badges}</div>'

def topbar(title,left=None,right=''):
    l=f'<button aria-label="Back" style="border:0;background:transparent;padding:8px;margin-left:-8px;display:flex">{ic(left)}</button>' if left else ''
    return f'<div style="display:flex;align-items:center;gap:8px;padding:8px 16px 8px 16px;min-height:56px;box-sizing:border-box">{l}<h1 style="margin:0;font-size:22px;line-height:28px;font-weight:600;color:var(--ink);flex:1">{title}</h1>{right}</div>'

def iconbtn(name,label): return f'<button aria-label="{label}" style="border:0;background:transparent;padding:8px;display:flex;border-radius:999px">{ic(name)}</button>'

def navbar(active):
    items=[('library','Library'),('people','Accounts'),('activity','Activity'),('settings','Settings')]
    out=''
    for n,l in items:
        a=n==active
        pillbg='background:var(--brand-container);' if a else ''
        col='var(--on-brand-container)' if a else 'var(--ink-muted)'
        tc='var(--ink)' if a else 'var(--ink-muted)'
        out+=f'<a href="#" style="text-decoration:none;flex:1;display:flex;flex-direction:column;align-items:center;gap:4px"><span style="width:56px;height:30px;border-radius:999px;display:flex;align-items:center;justify-content:center;{pillbg}">{ic(n,22,col,2 if a else 1.8)}</span><span style="font-size:12px;line-height:16px;font-weight:{600 if a else 500};color:{tc}">{l}</span></a>'
    return f'<nav style="position:absolute;left:0;right:0;bottom:0;height:80px;background:var(--surface-container);display:flex;align-items:flex-start;padding-top:12px;box-sizing:border-box;border-top:1px solid var(--outline)">{out}</nav>'

def btn(text,kind='filled',icon=None,full=False):
    w='width:100%;' if full else ''
    i=ic(icon,18,'var(--on-brand)' if kind=='filled' else 'var(--on-brand-container)' if kind=='tonal' else 'var(--brand)',2) if icon else ''
    if kind=='filled': s='background:var(--brand);color:var(--on-brand);border:0;'
    elif kind=='tonal': s='background:var(--brand-container);color:var(--on-brand-container);border:0;'
    else: s='background:transparent;color:var(--brand);border:1px solid var(--outline-strong);'
    return f'<button style="{s}{w}height:48px;padding:0 20px;border-radius:999px;font:500 15px/20px Roboto,sans-serif;display:inline-flex;align-items:center;justify-content:center;gap:8px;box-sizing:border-box">{i}{text}</button>'

def page(title,th,body,bg='var(--surface)'):
    return f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;600;700&amp;display=swap" rel="stylesheet">
<style>
body{{margin:0}}
a{{color:var(--brand)}}a:hover{{color:var(--brand-pressed)}}
.t{{{vars_for(th)}}}
</style>
</helmet>
<div class="t" style="position:relative;width:390px;height:844px;overflow:hidden;background:{bg};font-family:Roboto,system-ui,sans-serif;color:var(--ink)">
{body}
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":390,"height":844}}}}'>
class Component extends DCLogic {{
renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
'''
SB='<div style="height:28px"></div>'  # space for system status bar (not drawn)

# ---------- screens ----------
def welcome(th):
    return SB+f'''<div style="padding:40px 24px 0;display:flex;flex-direction:column;gap:20px">
<img src="{MARK[th]}" alt="Storize logo" width="72" height="72" style="border-radius:18px">
<div><h1 style="margin:0;font-size:34px;line-height:40px;font-weight:700;letter-spacing:-.5px">Stories disappear.<br>Yours don't have to.</h1>
<p style="margin:12px 0 0;font-size:15px;line-height:22px;color:var(--ink-muted)">Storize saves the stories, posts and highlights of the accounts you choose, straight to your gallery, in the background.</p></div>
<div style="display:flex;flex-direction:column;gap:12px;margin-top:4px">
<div style="display:flex;gap:12px;align-items:flex-start">{ic('download',22,'var(--brand)')}<div><div style="font-weight:500;font-size:15px">Automatic</div><div style="font-size:13px;color:var(--ink-muted)">New stories and posts are saved as they appear.</div></div></div>
<div style="display:flex;gap:12px;align-items:flex-start">{ic('eye',22,'var(--brand)')}<div><div style="font-weight:500;font-size:15px">Never marked as seen</div><div style="font-size:13px;color:var(--ink-muted)">Viewing for archiving doesn't show up in their viewers list.</div></div></div>
<div style="display:flex;gap:12px;align-items:flex-start">{ic('lock',22,'var(--brand)')}<div><div style="font-weight:500;font-size:15px">Stays on your phone</div><div style="font-size:13px;color:var(--ink-muted)">No servers. Your login never leaves the device.</div></div></div>
</div>
<div style="padding:14px 16px;border-radius:20px;background:var(--surface-container);display:flex;gap:12px">{ic('warn',22,'var(--warning)')}<div style="font-size:13px;line-height:18px;color:var(--ink)">Use a dedicated Instagram account. Instagram may ask it to verify or limit it.</div></div>
</div>
<div style="position:absolute;left:24px;right:24px;bottom:40px;display:flex;flex-direction:column;gap:12px">{btn('Get started','filled',full=True)}<a href="#" style="text-align:center;font-size:14px;text-decoration:none;font-weight:500">I already have an account set up</a></div>'''

def library(th):
    grid=''
    days=[('Today',[0,1,2,3,4,5],{0:'new',1:'v0:14',4:'c3'}),('Yesterday',[6,7,8],{6:'v0:31'})]
    for d,ids,mark in days:
        cells=''
        for k,i in enumerate(ids):
            m=mark.get(k,'')
            cells+=thumb(i,114,170,new=(m=='new' or (d=='Today' and k<2)),video=m[1:] if m.startswith('v') else None,carousel=m[1:] if m.startswith('c') else None)
        grid+=f'<div style="display:flex;align-items:center;justify-content:space-between;margin:16px 0 8px"><span style="font-size:13px;font-weight:600;color:var(--ink-muted);letter-spacing:.3px">{d}</span><span style="font-size:12px;color:var(--ink-muted)">{len(ids)} items</span></div><div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px">{cells}</div>'
    accts=''.join(chip(t,s) for t,s in [('All',True),('@nour_k',False),('@brandx',False),('@client_co',False)])
    return SB+topbar('Library',right=iconbtn('search','Search')+iconbtn('filter','Filters'))+f'''<div style="padding:0 16px">
<div style="display:flex;gap:4px;padding:4px;border-radius:999px;background:var(--surface-container)">
<button style="flex:1;border:0;height:36px;border-radius:999px;background:var(--surface);color:var(--ink);font:600 13px Roboto;box-shadow:0 1px 2px rgba(0,0,0,.08)">Stories <span style="margin-left:4px;padding:1px 7px;border-radius:999px;background:var(--accent-container);color:var(--accent);font-size:11px">12 new</span></button>
<button style="flex:1;border:0;height:36px;border-radius:999px;background:transparent;color:var(--ink-muted);font:500 13px Roboto">Posts</button>
<button style="flex:1;border:0;height:36px;border-radius:999px;background:transparent;color:var(--ink-muted);font:500 13px Roboto">Highlights</button></div>
<div style="display:flex;gap:8px;margin-top:12px;overflow:hidden">{accts}</div>
{grid}</div>'''+navbar('library')

def accounts(th):
    rows=[('N','#C9714E','@nour_k','Nour K.','active','3 new today · 128 saved',True),
          ('B','#5E7CB0','@brandx','Brand X','checking','Checking now…',False),
          ('C','#5E9A7C','@client_co','Client Co','active','Last story 2 h ago · 57 saved',False),
          ('M','#A0729A','@maya.art','Maya','paused','Paused by you · 42 saved',False),
          ('S','#8A847E','@sami.dev','','waiting','Instagram asked us to slow down',False)]
    out=''
    for L,c,u,n,st,meta,ring in rows:
        lab={'active':'Active','checking':'Checking','paused':'Paused','waiting':'Waiting to look up'}[st]
        out+=f'<a href="#" style="text-decoration:none;color:inherit;display:flex;gap:12px;align-items:center;padding:12px 16px;min-height:72px;box-sizing:border-box">{avatar(L,c,44,ring)}<div style="flex:1;min-width:0"><div style="display:flex;align-items:center;gap:8px"><span style="font-size:16px;font-weight:500">{u}</span></div><div style="font-size:13px;color:var(--ink-muted);margin-top:2px">{meta}</div></div>{pill(lab,st)}</a>'
    right=iconbtn('refresh','Check now')+iconbtn('more','More options')
    return SB+topbar('Accounts',right=right)+f'''<div style="padding:0 16px 8px;font-size:13px;color:var(--ink-muted)">5 of 50 · next check in 12 min</div>
<div style="margin:0 12px;border-radius:20px;background:var(--surface-container);overflow:hidden">{out}</div>
<div style="position:absolute;right:16px;bottom:100px">{btn('Add account','filled','plus')}</div>'''+navbar('people')

def add_account(th):
    cat=''
    for t,d,s in [('My own or a client’s','Accounts you run',False),('Someone who agreed','They know you archive them',True),('Public creator or brand','A public account',False)]:
        bd='2px solid var(--brand)' if s else '1px solid var(--outline)'
        dot=f'<span style="width:20px;height:20px;border-radius:999px;border:2px solid {"var(--brand)" if s else "var(--outline-strong)"};display:flex;align-items:center;justify-content:center;flex:none">{"<span style=\'width:10px;height:10px;border-radius:999px;background:var(--brand)\'></span>" if s else ""}</span>'
        cat+=f'<label style="display:flex;gap:12px;align-items:center;padding:12px 14px;border-radius:14px;border:{bd};background:var(--surface)">{dot}<span><span style="display:block;font-size:15px;font-weight:500">{t}</span><span style="display:block;font-size:12px;color:var(--ink-muted)">{d}</span></span></label>'
    hist=''.join(chip(t,s) for t,s in [('None',False),('Today',False),('7 days',True),('30 days',False),('All',False)])
    return SB+topbar('Add account','close')+f'''<div style="padding:4px 16px 0;display:flex;flex-direction:column;gap:18px">
<div><label for="u" style="font-size:13px;font-weight:500;color:var(--ink-muted)">Instagram username or link</label>
<div style="display:flex;gap:8px;margin-top:6px"><div style="flex:1;display:flex;align-items:center;gap:6px;height:52px;padding:0 14px;border-radius:12px;border:2px solid var(--brand);background:var(--surface-container-high)"><span style="color:var(--ink-muted)">@</span><input id="u" value="nour_k" style="border:0;background:transparent;font:400 16px Roboto;color:var(--ink);outline:none;width:100%"></div>
{btn('Preview','tonal','eye')}</div></div>
<div><div style="font-size:13px;font-weight:500;color:var(--ink-muted);margin-bottom:8px">Who is this?</div><div style="display:flex;flex-direction:column;gap:8px">{cat}</div></div>
<div><div style="font-size:13px;font-weight:500;color:var(--ink-muted);margin-bottom:8px">Save automatically</div><div style="display:flex;gap:8px">{chip('Stories',True)}{chip('Posts',True)}{chip('Highlights',False)}</div></div>
<div><div style="font-size:13px;font-weight:500;color:var(--ink-muted);margin-bottom:8px">Older posts</div><div style="display:flex;gap:6px;flex-wrap:wrap">{hist}</div>
<div style="font-size:12px;color:var(--ink-muted);margin-top:6px">Downloads slowly in the background.</div></div>
</div>
<div style="position:absolute;left:16px;right:16px;bottom:28px">{btn('Add account','filled',full=True)}</div>'''

def preview(th):
    stories=''.join(thumb(i,92,150,new=True,video=('0:12' if i==1 else None),check=(True if i<2 else False)) for i in range(3))
    posts=''
    for i in range(6):
        posts+=thumb(i+3,114,114,video=('0:42' if i==2 else None),carousel=('4' if i==0 else None),check=('saved' if i in (4,5) else (True if i in (0,1) else False)))
    return SB+topbar('Preview','back',right=iconbtn('more','More'))+f'''<div style="padding:0 16px;display:flex;flex-direction:column;gap:14px">
<div style="display:flex;gap:14px;align-items:center">{avatar('N','#C9714E',60,True)}<div><div style="font-size:18px;font-weight:600">Nour K.</div><div style="font-size:14px;color:var(--ink-muted)">@nour_k · public</div><div style="font-size:12px;color:var(--ink-muted);margin-top:2px">3 stories now · 214 posts</div></div></div>
<div><div style="display:flex;justify-content:space-between;align-items:baseline"><h2 style="margin:0;font-size:17px;font-weight:600">Current stories</h2><span style="font-size:12px;color:var(--ink-muted)">expire in 6–20 h</span></div>
<div style="display:flex;gap:8px;margin-top:8px">{stories}</div></div>
<div><div style="display:flex;justify-content:space-between;align-items:baseline"><h2 style="margin:0;font-size:17px;font-weight:600">Recent posts</h2><a href="#" style="font-size:13px;font-weight:500;text-decoration:none">Select all</a></div>
<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:8px">{posts}</div></div></div>
<div style="position:absolute;left:0;right:0;bottom:0;padding:12px 16px 24px;background:var(--surface-container);border-top:1px solid var(--outline);display:flex;flex-direction:column;gap:10px">
<div style="display:flex;gap:8px">{btn('Save 4 selected','filled','download')}{btn('Save all','tonal')}</div>
<a href="#" style="text-align:center;font-size:14px;font-weight:500;text-decoration:none">Track this account automatically</a></div>'''

def detail(th):
    stat=lambda v,l: f'<div style="flex:1;padding:12px;border-radius:16px;background:var(--surface-container)"><div style="font-size:24px;line-height:28px;font-weight:600">{v}</div><div style="font-size:12px;color:var(--ink-muted)">{l}</div></div>'
    grid=''.join(thumb(i,114,150,video=('0:09' if i==2 else None),hl=(i==3)) for i in range(6))
    return SB+topbar('@nour_k','back',right=iconbtn('more','More options'))+f'''<div style="padding:0 16px;display:flex;flex-direction:column;gap:14px">
<div style="display:flex;gap:14px;align-items:center">{avatar('N','#C9714E',56)}<div style="flex:1"><div style="font-size:18px;font-weight:600">Nour K.</div><div style="margin-top:4px">{pill('Active','active')}</div></div></div>
<div style="display:flex;gap:8px">{stat('128','stories')}{stat('46','posts')}{stat('412 MB','space')}</div>
<div style="padding:14px;border-radius:16px;background:var(--surface-container)"><div style="display:flex;justify-content:space-between;align-items:center"><span style="font-size:15px;font-weight:500">Post history · 7 days</span><span style="font-size:12px;color:var(--ink-muted)">31 of ~40</span></div>
<div style="height:6px;border-radius:999px;background:var(--surface-container-high);margin:10px 0"><div style="width:76%;height:6px;border-radius:999px;background:var(--brand)"></div></div>
<div style="display:flex;gap:8px">{btn('Pause history','outline','pause')}</div></div>
<div style="display:flex;gap:8px">{btn('Preview &amp; save','tonal','eye')}{btn('Check now','outline','refresh')}</div>
<div style="display:flex;justify-content:space-between;align-items:baseline"><h2 style="margin:0;font-size:17px;font-weight:600">Saved</h2><a href="#" style="font-size:13px;font-weight:500;text-decoration:none">See all</a></div>
<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px">{grid}</div></div>'''

def viewer(th):
    return f'''<div style="position:absolute;inset:0;background:#000"></div>
<div style="position:absolute;left:0;right:0;top:60px;bottom:96px;background:{PH[0]};border-radius:16px;margin:0 4px;overflow:hidden"><div style="position:absolute;left:20%;top:30%;width:60%;height:30%;border-radius:999px;background:rgba(255,255,255,.18)"></div></div>
<div style="position:absolute;left:12px;right:12px;top:36px;display:flex;gap:4px">{''.join(f'<div style="flex:1;height:3px;border-radius:999px;background:{"#fff" if k<1 else "rgba(255,255,255,.4)"}"></div>' for k in range(3))}</div>
<div style="position:absolute;left:16px;right:8px;top:72px;display:flex;align-items:center;gap:10px">{avatar('N','#C9714E',34)}<div style="flex:1;color:#fff"><div style="font-size:14px;font-weight:600">@nour_k</div><div style="font-size:12px;opacity:.85">Today 10:15 · saved</div></div><button aria-label="Close" style="border:0;background:transparent;padding:8px;display:flex">{ic('close',24,'#fff')}</button></div>
<div style="position:absolute;left:16px;right:16px;bottom:118px;display:flex;align-items:center;gap:8px;padding:8px 12px;border-radius:12px;background:var(--media-scrim);color:#fff;font-size:12px">{ic('check',16,'#fff',2.2)}In your gallery · Pictures/Storize/nour_k</div>
<div style="position:absolute;left:0;right:0;bottom:0;height:96px;display:flex;justify-content:space-around;align-items:center">{''.join(f'<button style="border:0;background:transparent;color:#fff;display:flex;flex-direction:column;align-items:center;gap:4px;font:500 12px Roboto">{ic(n,24,"#fff")}{l}</button>' for n,l in [('share','Share'),('info','Info'),('trash','Delete')])}</div>'''

def settings(th):
    def row(icon,t,v='',sw=None):
        right=f'<span style="font-size:14px;color:var(--ink-muted)">{v}</span>{ic("chevron",18,"var(--ink-muted)")}' if sw is None else f'<span style="width:48px;height:28px;border-radius:999px;background:{"var(--brand)" if sw else "var(--surface-container-high)"};position:relative;flex:none;{"" if sw else "border:2px solid var(--outline-strong);box-sizing:border-box"}"><span style="position:absolute;top:{4 if sw else 4}px;{"right:4px" if sw else "left:4px"};width:{20 if sw else 16}px;height:{20 if sw else 16}px;border-radius:999px;background:{"var(--on-brand)" if sw else "var(--outline-strong)"};{"top:4px" if sw else "top:4px"}"></span></span>'
        return f'<div style="display:flex;align-items:center;gap:14px;padding:0 16px;min-height:56px">{ic(icon,22,"var(--ink-muted)")}<span style="flex:1;font-size:15px">{t}</span>{right}</div>'
    seg=''
    for n,l,s in [('phone','System',False),('sun','Light',th=='light'),('moon','Dark',th=='dark')]:
        st='background:var(--brand-container);color:var(--on-brand-container);' if s else 'background:transparent;color:var(--ink);'
        seg+=f'<button style="flex:1;border:0;height:44px;border-radius:999px;{st}font:500 13px Roboto;display:flex;align-items:center;justify-content:center;gap:6px">{ic(n,18,"var(--on-brand-container)" if s else "var(--ink-muted)")}{l}</button>'
    sec=lambda t: f'<div style="padding:18px 16px 6px;font-size:12px;font-weight:600;letter-spacing:.6px;color:var(--brand)">{t}</div>'
    card=lambda inner: f'<div style="margin:0 12px;border-radius:20px;background:var(--surface-container);overflow:hidden">{inner}</div>'
    return SB+topbar('Settings')+f'''{sec('APPEARANCE')}
<div style="margin:0 12px;padding:6px;border-radius:999px;background:var(--surface-container);display:flex;gap:4px">{seg}</div>
<div style="padding:6px 20px 0;font-size:12px;color:var(--ink-muted)">System follows your phone's light or dark setting.</div>
{sec('INSTAGRAM')}{card(f'<div style="display:flex;align-items:center;gap:12px;padding:12px 16px">{avatar("S","#6F9DA6",40)}<div style="flex:1"><div style="font-size:15px;font-weight:500">@storize_archive</div><div style="font-size:12px;color:var(--ink-muted)">Logged in</div></div>{pill("Active","active")}</div>')}
{sec('CHECKING')}{card(row('refresh','Check stories every','30 min')+row('download','Check posts every','3 h')+row('phone','Wi-Fi only',sw=False))}
{sec('NOTIFICATIONS')}{card(row('bell','New stories',sw=True)+row('warn','Login problems',sw=True))}'''+navbar('settings')

SCREENS=[('Welcome',welcome),('Library',library),('Accounts',accounts),('AddAccount',add_account),('Preview',preview),('AccountDetail',detail),('StoryViewer',viewer),('Settings',settings)]
boards={};order=[]
titles={'Welcome':'S-01 Welcome','Library':'S-04 Library','Accounts':'S-07 Accounts','AddAccount':'S-08 Add account','Preview':'S-16 Preview & save (new)','AccountDetail':'S-09 Account detail','StoryViewer':'S-06 Story viewer','Settings':'S-12 Settings · Appearance'}
for row,th in enumerate(['light','dark']):
    for col,(name,fn) in enumerate(SCREENS):
        fname=f'{name}{"Dark" if th=="dark" else ""}.dc.html'
        if name=='Welcome' and th=='light': fname='Main.dc.html'
        bg='#000' if name=='StoryViewer' else 'var(--surface)'
        open(os.path.join(OUT,fname),'w').write(page(f'{titles[name]} ({th})',th,fn(th),bg))
        boards[fname]={'x':col*(390+80),'y':row*(844+340),'w':390,'h':844,'title':f'{titles[name]} · {"Light" if th=="light" else "Dark"}'}
        order.append(fname)
canvas={"v":3,"createdOnFiles":{"v":1,"at":"2026-11-26T18:20:00Z"},"title":"Storize — UI mockups (light & dark)","launch":{"view":"canvas"},"pages":[],
"boards":boards,"order":order,
"notes":{"lt":{"x":0,"y":-300,"text":"Light theme","kind":"title1","maxW":3680},"dt":{"x":0,"y":844+340-260,"text":"Dark theme","kind":"title1","maxW":3680}},
"designSystems":[{"title":"Storize","namespace":"storize","artifact":"https://claude.ai/artifact/9FEb7nf23n6eaXUh2W2r6M","version":None,"copiedAt":"2026-11-26T18:20:00Z"}]}
json.dump(canvas,open(os.path.join(OUT,'canvas.json'),'w'),indent=1)
print(order)
print({f:os.path.getsize(os.path.join(OUT,f)) for f in order})
