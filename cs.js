/* 첫소절 — 공용 스크립트 */
var CS = {};
/* ── 앱(아이폰 · 안드로이드) 안에서 열렸는가 ──
   아이폰 앱은 문서 시작 때 window.CS_APP = 'ios' 와 window.CSNative 를 심고, 안드로이드 앱은 window.CSAndroid 창구를 붙입니다. */
CS.app = window.CSAndroid ? 'android' : (window.CS_APP === 'ios' || (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.csIOS)) ? 'ios' : null;
try { if (CS.app) sessionStorage.setItem('cs_app', CS.app); else if (sessionStorage.getItem('cs_app') && /CheotsojeolApp/.test(navigator.userAgent)) CS.app = sessionStorage.getItem('cs_app'); } catch (e) {}
if (CS.app) document.documentElement.classList.add('in-app', 'in-' + CS.app);
/* 화면 오류를 눈에 보이게(원격 확인용) — 빨간 띠를 누르면 닫힙니다 */
CS.errs = [];
window.addEventListener('error', function(e){ CS.showErr((e.message || 'error') + ' @' + String(e.filename || '').split('/').pop() + ':' + (e.lineno || '')); });
window.addEventListener('unhandledrejection', function(e){ var r = e.reason; CS.showErr('promise: ' + (r && (r.message || r.error_description) || String(r)).slice(0, 160)); });
CS.showErr = function(m){ CS.errs.push(m); try { var d = document.getElementById('csErr'); if (!d) { d = document.createElement('div'); d.id = 'csErr'; d.style.cssText = 'position:fixed;left:8px;right:8px;bottom:64px;z-index:99;background:#B3261E;color:#fff;font:12px/1.5 monospace;padding:8px 10px;border-radius:8px;white-space:pre-wrap;max-height:30vh;overflow:auto'; d.onclick = function(){ d.remove(); }; (document.body || document.documentElement).appendChild(d); } d.textContent = '⚠ ' + CS.errs.slice(-4).join('\n⚠ '); } catch (x) {} };
/* ── 언어(한국어 / English) ── */
CS.lang = (function(){ try { var v = localStorage.getItem('cs_lang'); if (v === 'ko' || v === 'en') return v; } catch (e) {} return /^ko/i.test(navigator.language || 'ko') ? 'ko' : 'en'; })();
document.documentElement.lang = CS.lang;
CS.T = function(ko, en){ return CS.lang === 'en' && en != null ? en : ko; };
CS.setLang = function(l){ try { localStorage.setItem('cs_lang', l); } catch (e) {} location.reload(); };
CS.GEN_EN = { '전체':'All', '발라드':'Ballad', '댄스':'Dance', '팝':'Pop', '힙합':'Hip-hop', 'R&B':'R&B', '어쿠스틱':'Acoustic', '록':'Rock', '트로트':'Trot', '재즈':'Jazz', '클래식':'Classical', '동요':'Kids', 'CCM':'CCM', '광고 · 배경음악':'Ads · BGM' };
CS.G = function(g){ return CS.lang === 'en' ? (CS.GEN_EN[g] || g) : g; };
CS.SONGS = [
  { id:'s01', t:'새벽 세 시의 고백', by:'윤슬', genre:'발라드', mood:'잔잔한', bpm:72, key:'E♭', len:'3:48', price:3000000, mode:['양도','독점'], hue:[262,330], pv:true, plays:418, likes:57, isNew:true },
  { id:'s02', t:'Neon Runner', by:'J.Park', genre:'댄스', mood:'신나는', bpm:124, key:'F#m', len:'3:12', price:5000000, mode:['독점'], hue:[190,280], plays:902, likes:131 },
  { id:'s03', t:'봄비가 내리면', by:'하람', genre:'어쿠스틱', mood:'따뜻한', bpm:88, key:'G', len:'3:31', price:1500000, mode:['비독점'], hue:[140,60], pv:true, plays:265, likes:40, isNew:true },
  { id:'s04', t:'Gravity', by:'Mono Lake', genre:'R&B', mood:'몽환적', bpm:94, key:'Am', len:'3:55', price:4000000, mode:['양도','독점'], hue:[220,300], plays:640, likes:88 },
  { id:'s05', t:'우리 동네 슈퍼스타', by:'김가온', genre:'트로트', mood:'흥겨운', bpm:132, key:'C', len:'3:20', price:2000000, mode:['양도'], hue:[20,350], plays:1204, likes:176 },
  { id:'s06', t:'Paper Planes', by:'Sora', genre:'팝', mood:'청량한', bpm:110, key:'D', len:'3:05', price:2500000, mode:['독점','비독점'], hue:[180,120], pv:true, plays:533, likes:69, isNew:true },
  { id:'s07', t:'마지막 정류장', by:'은하수', genre:'록', mood:'뜨거운', bpm:146, key:'Em', len:'4:02', price:3500000, mode:['양도'], hue:[0,40], plays:377, likes:51 },
  { id:'s08', t:'광고 BGM · Morning Coffee', by:'Lumi', genre:'광고 · 배경음악', mood:'산뜻한', bpm:100, key:'A', len:'1:30', price:800000, mode:['비독점'], hue:[40,180], plays:288, likes:22 }
];
CS.GENRES = ['전체','발라드','댄스','팝','힙합','R&B','어쿠스틱','록','트로트','재즈','클래식','동요','CCM','광고 · 배경음악'];
CS.won = function(n){ n = +n || 0; if (CS.lang === 'en') return '₩' + n.toLocaleString('en-US'); return n >= 10000 ? (n / 10000).toLocaleString() + '만 원' : n.toLocaleString() + '원'; };
CS.art = function(s){ return 'background:linear-gradient(135deg,hsl(' + s.hue[0] + ' 62% 42%),hsl(' + s.hue[1] + ' 58% 30%))'; };
CS.wave = function(seed, n){ var h = ''; for (var i = 0; i < (n || 34); i++) { var v = Math.abs(Math.sin(i * 1.7 + seed) * 0.7 + Math.sin(i * 0.43 + seed * 2) * 0.3); h += '<i style="height:' + Math.round(14 + v * 86) + '%"></i>'; } return h; };
CS.modeTag = function(m){ return '<span class="tag ' + (m === '양도' ? 'gold' : m === '독점' ? 'violet' : 'mint') + '">' + CS.T(m + (m === '양도' ? '' : ' 이용허락'), { '양도':'Buyout', '독점':'Exclusive license', '비독점':'Non-exclusive license' }[m]) + '</span>'; };
CS.card = function(s, i){
  return '<a class="card song" href="cs_song.html?id=' + s.id + '">' +
    '<div class="art" style="' + CS.art(s) + '"><div class="wave">' + CS.wave(i + 1) + '</div><span class="play">▶</span>' +
    (s.isNew ? '<span class="tag coral" style="position:relative">NEW</span>' : '') + '</div>' +
    '<div class="body"><div class="t">' + CS.esc(s.t) + '</div><div class="by">' + CS.esc(s.by) + ' · ' + s.len + '</div>' +
    '<div class="meta">' + (s.pv ? '<span class="tag coral">' + CS.T('▶ 15초 미리듣기', '▶ 15s preview') + '</span>' : '') + '<span class="tag">' + CS.esc(CS.G(s.genre)) + '</span>' + (s.mood ? '<span class="tag">' + CS.esc(s.mood) + '</span>' : '') + s.mode.map(CS.modeTag).join('') + '</div>' +
    '<div class="price"><span class="faint">' + CS.T('희망가', 'Asking price') + '</span><b>' + CS.won(s.price) + '</b></div></div></a>';
};
CS.top = function(on){
  var T = CS.T, items = [['cs_index.html',T('둘러보기','Browse')],['cs_pass.html',T('청취권','Passes')],['cs_apply.html',T('곡 등록 신청','Submit a song')],['cs_talk.html',T('협상방','Deals')],['cs_admin.html',T('심사함','Review')]];
  var h = '<header class="top"><div class="wrap"><a class="logo" href="cs_index.html"><span class="bar"><i style="height:45%"></i><i style="height:80%"></i><i style="height:60%"></i><i style="height:100%"></i></span>' + T('첫소절', 'Cheotsojeol') + '<small>' + T('새 노래가 처음 울리는 곳', 'Where new songs are heard first') + '</small></a><nav class="nav">' +
    items.map(function(x){ return '<a href="' + x[0] + '"' + (x[0] === on ? ' class="on"' : '') + '>' + x[1] + '</a>'; }).join('') +
    '<a href="#" id="csLang" title="Language">' + (CS.lang === 'en' ? '한국어' : 'EN') + '</a><a class="cta" id="csLogin" href="cs_login.html">' + T('로그인', 'Log in') + '</a></nav></div></header>';
  document.body.insertAdjacentHTML('afterbegin', h);
  document.getElementById('csLang').onclick = function(){ CS.setLang(CS.lang === 'en' ? 'ko' : 'en'); return false; };
  CS.me().then(function(m){ var a = document.getElementById('csLogin'); if (!a) return;
    var adm = document.querySelector('.nav a[href="cs_admin.html"]'); if (adm && !(m.profile && (m.profile.role === 'admin' || m.profile.role === 'reviewer'))) adm.style.display = 'none';
    if (m.user) { a.textContent = '👤 ' + (m.profile ? m.profile.nickname : T('내 정보', 'My page')); a.href = 'cs_me.html'; }
    else a.href = 'cs_login.html?next=' + encodeURIComponent(location.pathname.split('/').pop() + location.search); });
  document.body.insertAdjacentHTML('beforeend', (['cs_talk.html'].indexOf(on) >= 0 ? '<div class="preview">' + T('미리보기 · 준비 중인 화면입니다', 'Preview · coming soon') + '</div>' : '') +
    '<footer class="foot wrap"><b>' + T('첫소절(위브앱솔루션)은 통신판매중개자이며 통신판매의 당사자가 아닙니다. 곡, 곡 정보, 거래에 관한 의무와 책임은 판매자(작가)에게 있습니다.', 'Cheotsojeol (WEAPP Solution) is a marketplace intermediary and is not a party to the sale. The seller (songwriter) is responsible for the songs, song information and transactions.') + '</b><br>' +
    T('위브앱솔루션 · 대표 이미화 · 사업자등록번호 206-08-71754 · 통신판매업신고 2022-수원권선-1701<br>경기도 수원시 권선구 수성로47 10동 501호 · weapps.kr@gmail.com',
      'WEAPP Solution · CEO Mihwa Lee · Business reg. 206-08-71754 · Mail-order reg. 2022-Suwon Gwonseon-1701<br>10-501, 47 Suseong-ro, Gwonseon-gu, Suwon, Gyeonggi, Korea · weapps.kr@gmail.com') + '<br>' +
    '<a href="cs_terms.html">' + T('이용약관', 'Terms') + '</a> · <b><a href="cs_privacy.html">' + T('개인정보처리방침', 'Privacy Policy') + '</a></b> · <a href="cs_terms.html#author">' + T('작가 약관', 'Songwriter Terms') + '</a> · <a href="cs_terms.html#refund">' + T('취소 · 환불 규정', 'Refunds') + '</a></footer>');
};

/* ── 로그인 · 회원 정보 (Supabase) ── */
CS.diag = { ev: [] };
try { localStorage.setItem('cs_ls_test', '1'); CS.diag.ls = localStorage.getItem('cs_ls_test') === '1' ? 1 : 0; CS.diag.key = Object.keys(localStorage).some(function(k){ return /^sb-.*auth-token$/.test(k); }) ? 1 : 0; } catch (e) { CS.diag.ls = 0; CS.diag.key = 0; }
CS.sb = (window.supabase && window.CS_SUPABASE_URL) ? window.supabase.createClient(window.CS_SUPABASE_URL, window.CS_SUPABASE_KEY) : null;
CS._me = null;
CS._uid = null;
if (CS.sb) CS.sb.auth.onAuthStateChange(function(ev, ss){ CS.diag.ev.push(ev); CS._uid = ss && ss.user ? ss.user.id : null; if (CS._uid && CS.app) setTimeout(CS.storeFlush, 300); });
CS.me = function(force){
  if (CS._me && !force) return CS._me;
  CS._me = (async function(){
    if (!CS.sb) return { user: null };
    var r = await CS.sb.auth.getSession(); var u = r.data && r.data.session ? r.data.session.user : null;
    if (!u) return { user: null, err: r.error ? r.error.message : null };
    var p = await CS.sb.from('cs_profiles').select('id,nickname,role').eq('id', u.id).maybeSingle();
    var a = await CS.sb.from('cs_authors').select('user_id,display_name,trust_member,trust_society,tax_type').eq('user_id', u.id).maybeSingle();
    return { user: u, profile: p.data || null, author: a.data || null, err: (p.error || a.error) ? ((p.error || a.error).message + ' [' + ((p.error || a.error).code || '') + ']') : null };
  })();
  return CS._me;
};
CS.esc = function(t){ return String(t == null ? '' : t).replace(/[&<>"']/g, function(c){ return { '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]; }); };
CS.needLogin = async function(){
  var m = await CS.me();
  if (m.user && m.err) { var bx = document.querySelector('main') || document.body; bx.insertAdjacentHTML('afterbegin', '<div class="card" style="margin:24px 0;padding:18px;color:var(--coral);line-height:1.7">' + CS.T('회원 정보를 불러오지 못했습니다. 이 화면을 캡처해서 보내 주세요.', 'Could not load your account. Please send us a screenshot of this screen.') + '<br><span class="faint">' + CS.esc(m.err) + '</span></div>'); return null; }
  if (!m.user || !m.profile) { location.href = 'cs_login.html?next=' + encodeURIComponent(location.pathname.split('/').pop() + location.search) + '&why=' + (m.user ? 'nick' : 'nosession') + (m.user ? '' : '&ls=' + CS.diag.ls + '&k=' + CS.diag.key + '&ev=' + CS.diag.ev.join('.') + '&t=' + encodeURIComponent(new Date().toISOString().slice(0, 19)) + (m.err ? '&e=' + encodeURIComponent(m.err) : '')); return null; }
  return m;
};

/* ── 실제 곡(데이터베이스) → 화면용 ── */
CS.SONG_COLS = 'id,title,genre,mood,bpm,music_key,length_sec,intro,modes,price_krw,negotiable,preview_allowed,status,plays,likes,created_at,listed_at,author_id,cs_authors(display_name,bio,trust_member)';
CS.fromDb = function(r){
  var h = 0; for (var i = 0; i < r.id.length; i++) h = (h * 31 + r.id.charCodeAt(i)) % 360;
  var M = { transfer:'양도', exclusive:'독점', nonexclusive:'비독점' }, L = r.length_sec || 0;
  return { id: r.id, t: r.title, by: r.cs_authors ? r.cs_authors.display_name : '', genre: r.genre, mood: r.mood || '', bpm: r.bpm, key: r.music_key,
    len: L ? Math.floor(L / 60) + ':' + ('0' + L % 60).slice(-2) : '—', sec: L, price: r.price_krw, mode: (r.modes || []).map(function(m){ return M[m]; }),
    hue: [h, (h + 70) % 360], pv: r.preview_allowed, plays: r.plays || 0, likes: r.likes || 0, negotiable: r.negotiable, intro: r.intro,
    bio: r.cs_authors ? r.cs_authors.bio : '', author_id: r.author_id, status: r.status, listed_at: r.listed_at,
    isNew: r.listed_at && (Date.now() - new Date(r.listed_at).getTime()) < 14 * 864e5 };
};

/* ── 꾸미기: 주간 · 야간, 바탕색, 분위기(음표 · 눈 · 비 · 벚꽃 · 별밤 · 크리스마스), 오선지 ── */
CS.PAL_EN = { navy:'Navy', wine:'Wine', forest:'Forest', violet:'Violet', ink:'Ink', ivory:'Ivory', sky:'Sky', pink:'Blossom', mint:'Mint', white:'Light gray' };
CS.PAL = {
  dark: { navy:['남색','#0E1020','#171A2E','#1F2340'], wine:['와인','#1A0E14','#26151D','#331C27'], forest:['숲','#0B1613','#13221D','#1A2D27'],
          violet:['보라','#130E22','#1D1633','#271E44'], ink:['먹색','#101010','#1A1A1A','#252525'] },
  light:{ ivory:['아이보리','#EADFC8','#FBF7EE','#E2D6BC'], sky:['하늘','#D9E6F4','#F7FAFE','#CCDCEE'], pink:['벚꽃','#F2DCE1','#FDF6F7','#EACFD6'],
          mint:['민트','#D7EBE1','#F6FBF8','#C8E2D5'], white:['회백색','#E6E6EA','#FAFAFB','#DADADF'] } };
CS.FX = [['notes',CS.T('🎵 음표','🎵 Notes')],['none',CS.T('없음','None')],['snow',CS.T('❄ 눈','❄ Snow')],['rain',CS.T('🌧 비','🌧 Rain')],['petal',CS.T('🌸 벚꽃','🌸 Blossoms')],['stars',CS.T('✨ 별밤','✨ Starry night')],['xmas',CS.T('🎄 크리스마스','🎄 Christmas')]];
CS.deco = (function(){ var d = { mode:'auto', dark:'navy', light:'ivory', fx:'notes', staff:false }; try { var x = JSON.parse(localStorage.getItem('cs_deco') || '{}'); for (var k in x) d[k] = x[k]; } catch (e) {} return d; })();
CS.isLight = function(){ return CS.deco.mode === 'light' || (CS.deco.mode === 'auto' && !(window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches) && (new Date().getHours() >= 7 && new Date().getHours() < 19)); };
CS.applyDeco = function(){
  var L = CS.isLight(), p = L ? CS.PAL.light[CS.deco.light] || CS.PAL.light.ivory : CS.PAL.dark[CS.deco.dark] || CS.PAL.dark.navy, r = document.documentElement, st = r.style;
  r.setAttribute('data-mode', L ? 'light' : 'dark'); r.classList.toggle('staff', !!CS.deco.staff);
  st.setProperty('--bg', p[1]); st.setProperty('--panel', p[2]); st.setProperty('--panel2', p[3]);
  st.setProperty('--topbg', L ? 'rgba(255,255,255,.85)' : p[1] + 'DD');
  st.setProperty('--line', L ? 'rgba(20,20,40,.12)' : 'rgba(255,255,255,.10)');
  st.setProperty('--text', L ? '#1B1C24' : '#EEF0F7'); st.setProperty('--dim', L ? '#4E5266' : '#A9AFC6'); st.setProperty('--faint', L ? '#80849A' : '#7A809A');
  st.setProperty('--gold', L ? '#B9862C' : '#E8B65A'); st.setProperty('--mint', L ? '#2E9A6E' : '#7FD8B0'); st.setProperty('--violet', L ? '#6D5BE0' : '#9C8CFF'); st.setProperty('--coral', L ? '#E0603E' : '#F07A5A');
  st.setProperty('--staff', L ? 'rgba(70,55,30,.20)' : 'rgba(232,182,90,.32)');
  if (CS.fx) CS.fx.set(CS.deco.fx);
};
CS.saveDeco = function(){ try { localStorage.setItem('cs_deco', JSON.stringify(CS.deco)); } catch (e) {} CS.applyDeco(); CS.paintDeco(); };
CS.applyDeco();

/* 움직이는 배경(캔버스) */
CS.fx = (function(){
  var cv, cx, W, H, P = [], kind = 'none', raf = 0, t0 = 0, DPR = Math.min(2, window.devicePixelRatio || 1);
  var calm = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  function R(a, b){ return a + Math.random() * (b - a); }
  function size(){ W = innerWidth; H = innerHeight; cv.width = W * DPR; cv.height = H * DPR; cx.setTransform(DPR, 0, 0, DPR, 0, 0); }
  function count(){ var a = W * H / 1e4; return Math.round(Math.min(140, a * ({ snow:.55, rain:.9, petal:.25, stars:1.1, xmas:.5, notes:.18 })[kind])) || 0; }
  function make(init){
    var L = CS.isLight(), o = { x: R(0, W), y: init ? R(0, H) : -20 };
    if (kind === 'snow' || kind === 'xmas') { o.r = R(1, 3.4); o.vy = R(.3, 1.1); o.vx = R(-.3, .3); o.ph = R(0, 6); o.c = L ? 'rgba(150,170,200,' : 'rgba(255,255,255,'; o.a = R(.4, .9); }
    else if (kind === 'rain') { o.l = R(10, 22); o.vy = R(7, 12); o.vx = -1.6; o.a = R(.15, .4); o.c = L ? 'rgba(70,100,150,' : 'rgba(170,200,255,'; }
    else if (kind === 'petal') { o.r = R(4, 8); o.vy = R(.5, 1.3); o.vx = R(.2, 1); o.rot = R(0, 6); o.vr = R(-.03, .03); o.ph = R(0, 6); o.a = R(.55, .9); }
    else if (kind === 'stars') { o.y = R(0, H); o.r = R(.4, 1.6); o.ph = R(0, 6); o.sp = R(.01, .04); }
    else if (kind === 'notes') { o.y = init ? R(0, H) : H + 30; o.g = ['♪','♫','♩','♬','𝄞','♪','♫'][Math.floor(R(0, 6.99))]; o.s = R(18, 38); o.vy = -R(.2, .5); o.ph = R(0, 6); o.a = L ? R(.14, .3) : R(.3, .6); o.rot = R(-.3, .3); }
    return o;
  }
  var bulbs = [], shoot = null;
  function frame(t){
    raf = requestAnimationFrame(frame); var dt = Math.min(3, (t - t0) / 16.7 || 1); t0 = t;
    cx.clearRect(0, 0, W, H); var L = CS.isLight();
    if (kind === 'xmas') { bulbs.forEach(function(b){ var on = .45 + .55 * Math.abs(Math.sin(t / 700 + b.ph)); cx.beginPath(); cx.fillStyle = b.c; cx.globalAlpha = on * (L ? .55 : .8); cx.arc(b.x, b.y, 3.2, 0, 7); cx.fill();
      cx.globalAlpha = on * .18; cx.arc(b.x, b.y, 9, 0, 7); cx.fill(); }); cx.globalAlpha = 1;
      cx.strokeStyle = L ? 'rgba(40,80,40,.25)' : 'rgba(120,180,120,.25)'; cx.beginPath(); bulbs.forEach(function(b, i){ i ? cx.lineTo(b.x, b.y - 3) : cx.moveTo(b.x, b.y - 3); }); cx.stroke(); }
    P.forEach(function(o, i){
      if (kind === 'snow' || kind === 'xmas') { o.ph += .01 * dt; o.x += (o.vx + Math.sin(o.ph) * .3) * dt; o.y += o.vy * dt; cx.beginPath(); cx.fillStyle = o.c + o.a + ')'; cx.arc(o.x, o.y, o.r, 0, 7); cx.fill(); }
      else if (kind === 'rain') { o.x += o.vx * dt; o.y += o.vy * dt; cx.strokeStyle = o.c + o.a + ')'; cx.lineWidth = 1; cx.beginPath(); cx.moveTo(o.x, o.y); cx.lineTo(o.x + o.vx * 1.6, o.y + o.l); cx.stroke(); }
      else if (kind === 'petal') { o.ph += .02 * dt; o.rot += o.vr * dt; o.x += (o.vx + Math.sin(o.ph) * .6) * dt; o.y += o.vy * dt;
        cx.save(); cx.translate(o.x, o.y); cx.rotate(o.rot); cx.scale(1, .55 + .45 * Math.abs(Math.sin(o.ph))); cx.fillStyle = 'rgba(247,170,190,' + o.a + ')';
        cx.beginPath(); cx.ellipse(0, 0, o.r, o.r * .62, 0, 0, 7); cx.fill(); cx.fillStyle = 'rgba(255,215,225,' + o.a * .8 + ')'; cx.beginPath(); cx.ellipse(-o.r * .3, 0, o.r * .35, o.r * .25, 0, 0, 7); cx.fill(); cx.restore(); }
      else if (kind === 'stars') { o.ph += o.sp * dt; var a = .25 + .75 * Math.abs(Math.sin(o.ph)); cx.beginPath(); cx.fillStyle = L ? 'rgba(185,134,44,' + a * .6 + ')' : 'rgba(255,248,220,' + a + ')'; cx.arc(o.x, o.y, o.r, 0, 7); cx.fill(); }
      else if (kind === 'notes') { o.ph += .01 * dt; o.y += o.vy * dt; o.x += Math.sin(o.ph) * .25 * dt; cx.save(); cx.translate(o.x, o.y); cx.rotate(o.rot + Math.sin(o.ph) * .15);
        cx.fillStyle = (L ? 'rgba(150,110,40,' : 'rgba(232,182,90,') + o.a + ')'; cx.font = o.s + 'px serif'; cx.fillText(o.g, 0, 0); cx.restore(); }
      if (kind !== 'stars' && (o.y > H + 30 || o.y < -60 || o.x < -40 || o.x > W + 40)) P[i] = make(false);
    });
    if (kind === 'stars') { if (!shoot && Math.random() < .003 * dt) shoot = { x: R(W * .2, W), y: R(0, H * .4), l: 0 };
      if (shoot) { shoot.l += 14 * dt; var g = cx.createLinearGradient(shoot.x, shoot.y, shoot.x - shoot.l, shoot.y + shoot.l * .45); g.addColorStop(0, L ? 'rgba(185,134,44,.6)' : 'rgba(255,255,255,.9)'); g.addColorStop(1, 'rgba(255,255,255,0)');
        cx.strokeStyle = g; cx.lineWidth = 1.5; cx.beginPath(); cx.moveTo(shoot.x, shoot.y); cx.lineTo(shoot.x - Math.min(shoot.l, 120), shoot.y + Math.min(shoot.l, 120) * .45); cx.stroke(); shoot.x -= 6 * dt; shoot.y += 2.7 * dt; if (shoot.l > 260) shoot = null; } }
  }
  function start(){ cancelAnimationFrame(raf); P = []; if (!cv || kind === 'none' || calm) { if (cx) cx.clearRect(0, 0, W, H); return; }
    var n = count(); for (var i = 0; i < n; i++) P.push(make(true));
    bulbs = []; if (kind === 'xmas') { var cols = ['#FF5A5A','#FFD34E','#5AD17A','#5AB4FF','#FF8AD8'], k = Math.ceil(W / 46); for (var j = 0; j <= k; j++) bulbs.push({ x: j * 46 + 10, y: 74 + Math.sin(j * .7) * 8, c: cols[j % 5], ph: j }); }
    raf = requestAnimationFrame(frame); }
  function init(){ if (cv) return; cv = document.createElement('canvas'); cv.id = 'fx'; cv.setAttribute('aria-hidden', 'true'); document.body.prepend(cv); cx = cv.getContext('2d'); size();
    addEventListener('resize', function(){ size(); start(); });
    document.addEventListener('visibilitychange', function(){ if (document.hidden) cancelAnimationFrame(raf); else start(); }); start(); }
  return { init: init, set: function(k){ kind = k; if (cv) start(); } };
})();

/* 꾸미기 창 */
CS.paintDeco = function(){
  var box = document.getElementById('deco'); if (!box) return; var d = CS.deco, L = CS.isLight(), pal = L ? CS.PAL.light : CS.PAL.dark, cur = L ? d.light : d.dark;
  var T = CS.T;
  box.innerHTML = '<h4>' + T('밝기', 'Brightness') + '</h4><div class="opts">' + [['auto',T('🕒 자동','🕒 Auto')],['light',T('☀ 주간','☀ Day')],['dark',T('🌙 야간','🌙 Night')]].map(function(x){ return '<span class="chip' + (d.mode === x[0] ? ' on' : '') + '" data-m="' + x[0] + '">' + x[1] + '</span>'; }).join('') + '</div>' +
    '<h4>' + T('바탕색', 'Background') + ' (' + (L ? T('주간', 'day') : T('야간', 'night')) + ')</h4><div class="opts">' + Object.keys(pal).map(function(k){ return '<span class="sw' + (k === cur ? ' on' : '') + '" title="' + T(pal[k][0], CS.PAL_EN[k]) + '" data-b="' + k + '" style="background:linear-gradient(135deg,' + pal[k][1] + ' 50%,' + pal[k][3] + ' 50%)"></span>'; }).join('') + '</div>' +
    '<h4>' + T('분위기', 'Ambience') + '</h4><div class="opts">' + CS.FX.map(function(x){ return '<span class="chip' + (d.fx === x[0] ? ' on' : '') + '" data-f="' + x[0] + '">' + x[1] + '</span>'; }).join('') + '</div>' +
    '<h4>' + T('배경', 'Pattern') + '</h4><div class="opts"><span class="chip' + (d.staff ? ' on' : '') + '" data-s="1">' + T('🎼 오선지 무늬', '🎼 Music staff') + '</span></div>' +
    '<div class="hint" style="margin-top:12px">' + T('이 기기에만 저장됩니다.', 'Saved on this device only.') + (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches ? T(' 기기 설정(동작 줄이기) 때문에 움직이는 분위기는 꺼져 있습니다.', ' Animations are off because of your device’s Reduce Motion setting.') : '') + '</div>';
  box.querySelectorAll('[data-m]').forEach(function(e){ e.onclick = function(){ d.mode = e.dataset.m; CS.saveDeco(); }; });
  box.querySelectorAll('[data-b]').forEach(function(e){ e.onclick = function(){ if (CS.isLight()) d.light = e.dataset.b; else d.dark = e.dataset.b; CS.saveDeco(); }; });
  box.querySelectorAll('[data-f]').forEach(function(e){ e.onclick = function(){ d.fx = e.dataset.f; CS.saveDeco(); }; });
  box.querySelector('[data-s]').onclick = function(){ d.staff = !d.staff; CS.saveDeco(); };
};
CS.staticEn = function(root){ if (CS.lang !== 'en') return; root = root || document;
  root.querySelectorAll('[data-en]').forEach(function(e){ e.innerHTML = e.getAttribute('data-en'); });
  root.querySelectorAll('[data-en-ph]').forEach(function(e){ e.placeholder = e.getAttribute('data-en-ph'); });
  var t = document.querySelector('title[data-en]'); if (t) document.title = t.getAttribute('data-en'); };
document.addEventListener('DOMContentLoaded', function(){
  CS.staticEn();
  CS.fx.init(); CS.fx.set(CS.deco.fx);
  var b = document.createElement('button'); b.className = 'deco-btn'; b.title = CS.T('화면 꾸미기', 'Decorate'); b.setAttribute('aria-label', b.title); b.textContent = '🎨';
  var p = document.createElement('div'); p.className = 'deco'; p.id = 'deco';
  document.body.appendChild(b); document.body.appendChild(p);
  b.onclick = function(e){ e.stopPropagation(); p.classList.toggle('on'); CS.paintDeco(); };
  document.addEventListener('click', function(e){ if (p.classList.contains('on') && !p.contains(e.target) && e.target !== b) p.classList.remove('on'); });
  if (window.matchMedia) matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(){ if (CS.deco.mode === 'auto') CS.applyDeco(); });
  setInterval(function(){ if (CS.deco.mode === 'auto') CS.applyDeco(); }, 600000);
});

/* =====================================================================
   앱 결제 (App Store · Google Play)  — 2026-10-26
   화면 → 앱: CS.storeBuy('7d') → 아이폰 CSNative.buy(상품, 계정) · 안드로이드 CSAndroid.storeBuy(상품, 계정)
   앱 → 화면: window.csStoreEvent({ kind, sku, a: 영수증, b: 주문번호 }) — 'ok' 를 돌려줘야 앱이 넘긴 것으로 압니다
   영수증은 서버(cs-iap-verify)가 애플 · 구글에 직접 확인한 뒤에만 청취권을 넣고, 그 다음에 앱이 정리(finish · consume)합니다.
   ===================================================================== */
CS.SKU = { '7d': 'cs_pass7', '15d': 'cs_pass15', '30d': 'cs_pass30' };
CS.storeName = function(){ return CS.app === 'ios' ? 'App Store' : 'Google Play'; };
CS.storeBuy = function(k){
  var sku = CS.SKU[k]; if (!sku || !CS._uid) return false;
  try {
    if (CS.app === 'ios' && window.CSNative) { window.CSNative.buy(sku, CS._uid); return true; }
    if (CS.app === 'android' && window.CSAndroid) { window.CSAndroid.storeBuy(sku, CS._uid); return true; }
  } catch (e) { CS.showErr('storeBuy: ' + e.message); }
  return false;
};
CS.storeFlush = function(recover){
  try {
    if (CS.app === 'ios' && window.CSNative) window.CSNative.flush();
    if (CS.app === 'android' && window.CSAndroid) { window.CSAndroid.storeFlush(); if (recover && window.CSAndroid.storeRecover) window.CSAndroid.storeRecover(); }
  } catch (e) {}
};
CS.storeDone = function(token){
  try {
    if (CS.app === 'ios' && window.CSNative) window.CSNative.finish(token);
    if (CS.app === 'android' && window.CSAndroid) window.CSAndroid.storeConsume(token);
  } catch (e) {}
};
CS._busy = {};
CS.storeToast = function(t, bad){
  var d = document.getElementById('csToast'); if (!d) { d = document.createElement('div'); d.id = 'csToast'; d.style.cssText = 'position:fixed;left:50%;bottom:calc(24px + env(safe-area-inset-bottom,0px));transform:translateX(-50%);z-index:98;max-width:calc(100vw - 32px);padding:12px 16px;border-radius:12px;font-size:14px;line-height:1.5;box-shadow:0 10px 30px rgba(0,0,0,.4)'; (document.body || document.documentElement).appendChild(d); }
  d.style.background = bad ? '#B3261E' : '#E8B65A'; d.style.color = bad ? '#fff' : '#1B1405'; d.textContent = t; d.style.display = '';
  clearTimeout(CS._toastT); CS._toastT = setTimeout(function(){ d.style.display = 'none'; }, bad ? 7000 : 5000);
};
window.csStoreEvent = function(ev){
  if (!ev || !CS.sb) return 'wait';
  var T = CS.T, k = ev.kind;
  if (k === 'storePurchase') {
    if (!CS._uid) return 'wait';                       // 로그인 정보를 아직 못 읽음 → 앱이 잠시 뒤 다시 줍니다
    if (CS._busy[ev.a]) return 'ok';
    CS._busy[ev.a] = 1;
    CS.sb.functions.invoke('cs-iap-verify', { body: { sku: ev.sku, token: ev.a, orderId: ev.b || '' } }).then(function(r){
      var d = r.data || {};
      if (d.finish) CS.storeDone(ev.a);
      if (d.ok) CS.storeToast(T('✅ 청취권이 들어왔습니다', '✅ Your pass is active') + (d.ends_at ? T(' · ' + String(d.ends_at).slice(0, 10) + '까지', ' · until ' + String(d.ends_at).slice(0, 10)) : ''));
      else if (!d.canceled) CS.storeToast(T('결제는 되었지만 확인이 늦어지고 있습니다. 앱을 다시 열면 자동으로 다시 확인합니다.', 'Payment received but confirmation is delayed. It will retry when you reopen the app.') + (d.error ? ' (' + d.error + ')' : ''), true);
      document.dispatchEvent(new CustomEvent('cs-store', { detail: { kind: d.ok ? 'done' : 'fail', data: d, sku: ev.sku } }));
    }).catch(function(e){ CS.storeToast(T('확인 중 오류: ', 'Verification error: ') + e.message, true); }).finally(function(){ delete CS._busy[ev.a]; });
    return 'ok';
  }
  if (k === 'storeCanceled') { document.dispatchEvent(new CustomEvent('cs-store', { detail: { kind: 'cancel' } })); return 'ok'; }
  if (k === 'storePending') { CS.storeToast(T('결제가 아직 확정되지 않았습니다. 확정되면 자동으로 청취권이 들어옵니다.', 'Payment is pending. Your pass will be added once it completes.')); document.dispatchEvent(new CustomEvent('cs-store', { detail: { kind: 'pending' } })); return 'ok'; }
  if (k === 'storeOwned') return 'ok';
  if (k === 'storeError') { CS.storeToast(T('결제를 끝내지 못했습니다', 'Payment did not complete') + (ev.a ? ' — ' + ev.a : ''), true); document.dispatchEvent(new CustomEvent('cs-store', { detail: { kind: 'error', msg: ev.a } })); return 'ok'; }
  return 'ok';
};
