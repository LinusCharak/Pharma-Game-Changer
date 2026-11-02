/// Maps a product's startValue to its bundled HTML asset path.
///
/// To add a new product's content:
///   1. Put NEWPRODUCT.html inside assets/html/
///   2. Add 'NEWPRODUCT': 'assets/html/NEWPRODUCT.html' below
///   3. Give the product button startValue: 'NEWPRODUCT' in product_catalog.dart
///
/// No new Flutter screen is ever needed -- ProductHtmlScreen resolves
/// the file purely from this map.
///
/// 'KOFOL SF / CT / SIP' and 'KOFOL GARGLE / RUB / ROLL-ON' are
/// deliberately NOT mapped here -- those two combined buttons now open a
/// variant-picker popup instead (see product_variant_picker.dart), and
/// it's each individual variant's startValue ('KOFOL SF', 'KOFOL CT',
/// etc. below) that resolves to an actual HTML file.
const Map<String, String> productHtmlFiles = {
  'M2TONE': 'assets/html/M2TONE.html',
  'HYPONIDD-DM': 'assets/html/HYPONIDD_DM.html',
  'LIVOMYN FL': 'assets/html/LIVOMYN_FL.html',
  'PLAT-C': 'assets/html/PLAT_C.html',
  'LUNAREX': 'assets/html/LUNAREXFORTE.html',
  'M2TONE FORTE': 'assets/html/M2TONEFORTE.html',
  'ADDYZOA': 'assets/html/ADDYZOA.html',
  'HYPONIDD': 'assets/html/HYPONIDD.html',
  'ENDOTONE': 'assets/html/ENDOTONE.html',
  'CYSTOLIB NUTRA': 'assets/html/CYSTOLIB.html',
  'ZOAZEST NUTRA': 'assets/html/ZOAZEST.html',
  'EXPIJOY NUTRA': 'assets/html/EXPIJOY.html',
  'FEMIPLEX': 'assets/html/FEMIPLEX.html',
  'FEMIFORTE': 'assets/html/FEMIFORTE.html',
  'NEO': 'assets/html/NEO.html',
  'VOMITEB': 'assets/html/VOMITEB.html',
  'EVANOVA': 'assets/html/EVANOVA.html',
  'MANOLL': 'assets/html/MANOLL.html',
  'MANOLL NUTRA': 'assets/html/MANOLLNUTRA.html',
  'LIVOMYN': 'assets/html/LIVOMYN.html',
  'CALCURY': 'assets/html/CALCURY.html',
  'ALKA-5': 'assets/html/ALKA5.html',
  'POSEX FORTE': 'assets/html/POSEXFORTE.html',
  'VIVADONA': 'assets/html/VIVADONA.html',
  'GALAKOL': 'assets/html/GALAKOL.html',
  'OBENYL': 'assets/html/OBENYL.html',
  'MENTACALM': 'assets/html/MENTACALM.html',
  'GUMTONE': 'assets/html/GUMTONE.html',
  'OJUS': 'assets/html/OJUS.html',
  'PROSTEEZ': 'assets/html/PROSTEEZ.html',
  'OSTOLIEF NUTRA': 'assets/html/OSTOLIEFNUTRA.html',
  'CHROPAXE': 'assets/html/CHROPAXE.html',
  'HALEEZY': 'assets/html/HALEEZY.html',
  'RICHELTH': 'assets/html/RICHELTH.html',
  'ZZOWIN NUTRA': 'assets/html/ZZOWINNUTRA.html',
  'EXTRAMMUNE': 'assets/html/EXTRAMMUNE.html',
  // 'KOFOL SF' is shared by two places: Peadiatrician's standalone
  // button (direct navigation) and GP/CP's combined button (via the
  // variant picker) -- same product, same HTML, same startValue.
  'KOFOL SF': 'assets/html/KOFOL_SF.html',
  'KOFOL CT': 'assets/html/KOFOL_CT.html',
  'KOFOL SIP': 'assets/html/KOFOL_SIP.html',
  'KOFOL GARGLE': 'assets/html/KOFOL_GARGLE.html',
  'KOFOL RUB': 'assets/html/KOFOL_RUB.html',
  'KOFOL ROLL ON': 'assets/html/KOFOL_ROLL_ON.html',
  'AMLA': 'assets/html/AMLA.html',
  'ARJUNA': 'assets/html/ARJUNA.html',
  'HALDI': 'assets/html/HALDI.html',
  'NEEM': 'assets/html/NEEM.html',
  'SHILAJIT GOLD': 'assets/html/SHILAJIT.html',
};
