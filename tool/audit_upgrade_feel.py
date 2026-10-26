"""Read-only three-repository source inventory. No catalogue regeneration/publication.
Resolved gameplay measurements are produced separately; source matches are not
proof of mechanic execution or visual acceptance.
"""
from pathlib import Path
import hashlib, json, re, subprocess
ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT.parent / 'regun-server'
ADMIN = ROOT.parent / 'regun-admin'
OUT = ROOT / 'docs/validation/upgrade-feel-2026-10-25'

def read(path):
    return path.read_text()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()

def references(token, paths):
    return [dict(file=str(p.relative_to(ROOT.parent)), line=i)
            for p in paths for i, line in enumerate(read(p).splitlines(), 1)
            if token in line]

def main():
    plan = read(ROOT / 'docs/UPGRADE_FEEL_IMPLEMENTATION_PLAN.md')
    families = re.findall(r'^\| ([^|]+) \(`([^`]+)`\) \| ([^|]+) \| ([^|]+) \|$', plan, re.M)
    assert len(families) == 43
    progression = read(SERVER / 'spacetimedb/src/progression.ts')
    online = re.findall(r'^  (\w+): "(?:core|utility|special)",', read(SERVER / 'spacetimedb/src/upgrade_admission.ts'), re.M)
    fusion_block = progression.split('export const FUSIONS = {')[1].split('} as const;')[0]
    online_fusions = re.findall(r'^  (\w+):', fusion_block, re.M)
    source_paths = [p for p in (ROOT / 'lib').rglob('*.dart')
                    if any(s in str(p) for s in ['/systems/', '/components/', '/game.dart', '/notifiers/'])
                    and p.name not in ['rank_effect_values.dart', 'upgrade_details.dart', 'upgrade_offer_policy.dart']]
    inventory = []
    prototypes = {'heavyLoad', 'walkingSpeedIncrease', 'scrapArmour', 'hotShot', 'ricochet'}
    for title, key, recipe, evidence in families:
        inventory.append(dict(id=key, title=title.strip(), kind='family',
            status='baseline-audit', prototype=key in prototypes,
            rankLimit='pinned capacity minus starting charges' if key in ['dashCapacity', 'grenadeCapacity'] else 8,
            onlineAdmitted=key in online, activationDirection=recipe.strip(),
            requiredActualEvidence=evidence.strip(), sourceReferences=references('PowerUp.' + key, source_paths),
            resolvedProjection='GameState.rankValues / RankEffects.values',
            observation='unmeasured: source locations are candidates until controlled execution'))
    for key, title in [('firebreak','Firebreak'),('stormCircuit','Storm Circuit'),('minefield','Minefield'),('pinball','Pinball'),('breachEngine','Breach Engine'),('hunterSwarm','Hunter Swarm'),('kilnPact','Kiln Pact'),('groundWire','Ground Wire')]:
        inventory.append(dict(id=key,title=title,kind='fusion',onlineAdmitted=key in online_fusions,
            sourceReferences=references("'"+key+"'",source_paths),status='baseline-audit'))
    for key, title in [('sentry','Sentry Gun'),('aura','Aura Salad')]:
        inventory.append(dict(id='support:'+key,title=title,kind='support',prototype=key=='sentry',onlineAdmitted=True,
            capability=7,rankLimit=8,oldPinnedRankLimit=3,sourceReferences=references('SupportFamily.'+key,source_paths),
            observation='Deployment/landing/fire or field; no extra immediate deployment',status='baseline-audit'))
    for key,title in [('salvage','Scrap Cache'),('sprintDistanceIncrease','Long Dash')]:
        inventory.append(dict(id=key,title=title,kind='fallback' if key=='salvage' else 'legacy',onlineAdmitted=key=='salvage',
            sourceReferences=references('PowerUp.'+key,source_paths),status='baseline-audit'))
    catalog=json.loads(read(SERVER/'shared/balance/catalog-v1.json'))
    admin_catalog=json.loads(read(ADMIN/'assets/data/catalog.json'))
    mobile_text=read(ROOT/'lib/data/balance_catalog.dart')
    mobile_catalog=json.loads(mobile_text.split("r'''",1)[1].rsplit("'''",1)[0])
    assert catalog == admin_catalog == mobile_catalog, 'Catalogues differ; do not regenerate blindly'
    rank_mobile=ROOT/'lib/systems/rank_effect_values.dart'
    rank_admin=ADMIN/'lib/models/rank_effect_values.dart'
    assert sha(rank_mobile)==sha(rank_admin), 'Rank component copies differ'
    runtime_path=ROOT/'build/upgrade-feel-audit/prototype-runtime.json'
    observed=json.loads(runtime_path.read_text()) if runtime_path.exists() else []
    for entry in inventory:
        entry['controlledObservations']=[o for o in observed if o.get('mode')=='full' and
            ('support:'+o['family'] if o['family']=='sentry' else o['family'])==entry['id']]
        entry['timeToOpportunity']='See controlledObservations; other contexts remain unmeasured.'
        entry['expectedUsefulFrequency']='Conditional on real eligible mechanic, existing cooldowns, charges, RNG and caps. No guaranteed proc is added.'
    report=dict(schema=1,date='2026-10-25',acceptance='Not accepted; baseline/source audit only',
        projects={name:dict(path=str(path),head=git(path,'rev-parse','HEAD'),status=git(path,'status','--porcelain=v1'),
            manifestVersion=re.search(r'^version:\s*(.*)$',read(path/'pubspec.yaml'),re.M)[1] if (path/'pubspec.yaml').exists() else
            dict(combat=json.loads(read(path/'spacetimedb/package.json')).get('version'),identity=json.loads(read(path/'identity/package.json')).get('version')))
            for name,path in [('mobile',ROOT),('admin',ADMIN),('server-api',SERVER)]},
        catalog=dict(id=catalog['catalogId'],fieldCount=len(catalog['fields']),historicalCatalogues=len(catalog.get('previousCatalogs',[])),
            structuralParity=True,rankDartByteParity=True,rankSourceSha256=sha(rank_mobile)),
        admission=dict(nativeFamilies=43,nativeFusions=8,nativeSurvivors=10,nativeWeapons=24,
            onlineFamilies=online,onlineFusions=online_fusions,onlineWeapons=['shotgun','carbine','revolver','arcCaster','burstRifle'],
            onlineSurvivors=['rook','scrapper','warden'],versusSurvivors=['rook'],capability=7),
        entries=inventory,
        issues=[
            dict(id='A11',severity='P2',finding='Player locomotion currently uses phase-preserved 12Hz cycles, not traveled-distance gait. The plan assumption is inaccurate. Fleet Foot motion coherence still needs review; no gait/balance change is silently introduced.'),
            dict(id='A01',severity='P1',finding='Acceptance is a generic counter, with a gameplay recovery consumer. Bridge explicitly once; never emit another recovery.'),
            dict(id='A02',severity='P1',finding='No authored multi-frame survivor activation; survivorAction is one existing action frame. Do not relabel hurt/death as upgrade animation.'),
            dict(id='A03',severity='P1',finding='Server admits 35 families / 6 fusions / 5 weapons / 3 survivors. Catalogue preview availability is broader than combat admission.'),
            dict(id='A04',severity='P1',finding='Co-op choice resolves straight to active in index.ts; a local-only hold would diverge simulation and recovery.'),
            dict(id='A05',severity='P1',finding='Pinned catalogue digest includes catalogue identity. Same-field retained versions exist. Never replace saved/live values with newest defaults.'),
            dict(id='A06',severity='P2',finding='Brief picker copy can suppress movement deltas; confirmation needs resolved context without raw world units.'),
            dict(id='A07',severity='P2',finding='Intrinsic Revolver bounce must not be attributed to a purchased Ricochet proc; count total and purchased contribution separately.'),
            dict(id='A08',severity='P2',finding='Support is delayed and temporary, with unlimited sentry ammunition. Acceptance cannot fake landing/fire or promise player immunity.'),
            dict(id='A09',severity='P2',finding='Existing API rank/support previews already expose components. Reuse them; do not add balance knobs or regenerate/publish catalogue for cosmetics.'),
            dict(id='A10',severity='P1',finding='No player trials, controlled gameplay clips or phone performance measurements yet. Formula fixtures and source audit cannot close the review gate.'),
        ])
    status={'A01':'typed receipts implemented; old pulse bridged once','A02':'Rook shared fitting prototype only; other art gated','A03':'admission preserved and preview distinction surfaced','A04':'protocol8 shared authoritative hold implemented; old/mixed fallback retained','A05':'catalogue identity and numeric values untouched','A06':'truthful movement ratio in prototype','A07':'purchased-budget attribution implemented','A08':'real deployment and physical-release cue in prototype','A09':'existing previews reused; no numerical controls added','A10':'human gate and physical measurements pending','A11':'open visual diagnosis; no unreviewed gait/balance change'}
    for issue in report['issues']: issue['prototypeStatus']=status[issue['id']]
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'coverage.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(entries=len(inventory),families=len(families),onlineFamilies=len(online),catalog=report['catalog'],versions={k:v['manifestVersion'] for k,v in report['projects'].items()}),indent=2))
if __name__=='__main__': main()
