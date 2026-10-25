/* 첫소절 — 미리보기용 공용 스크립트 (보기 자료 · 진짜 음원 없음) */
var CS = {};
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
CS.won = function(n){ return n >= 10000 ? (n / 10000).toLocaleString() + '만 원' : n.toLocaleString() + '원'; };
CS.art = function(s){ return 'background:linear-gradient(135deg,hsl(' + s.hue[0] + ' 62% 42%),hsl(' + s.hue[1] + ' 58% 30%))'; };
CS.wave = function(seed, n){ var h = ''; for (var i = 0; i < (n || 34); i++) { var v = Math.abs(Math.sin(i * 1.7 + seed) * 0.7 + Math.sin(i * 0.43 + seed * 2) * 0.3); h += '<i style="height:' + Math.round(14 + v * 86) + '%"></i>'; } return h; };
CS.modeTag = function(m){ return '<span class="tag ' + (m === '양도' ? 'gold' : m === '독점' ? 'violet' : 'mint') + '">' + m + (m === '양도' ? '' : ' 이용허락') + '</span>'; };
CS.card = function(s, i){
  return '<a class="card song" href="cs_song.html?id=' + s.id + '">' +
    '<div class="art" style="' + CS.art(s) + '"><div class="wave">' + CS.wave(i + 1) + '</div><span class="play">▶</span>' +
    (s.isNew ? '<span class="tag coral" style="position:relative">NEW</span>' : '') + '</div>' +
    '<div class="body"><div class="t">' + CS.esc(s.t) + '</div><div class="by">' + CS.esc(s.by) + ' · ' + s.len + '</div>' +
    '<div class="meta">' + (s.pv ? '<span class="tag coral">▶ 15초 미리듣기</span>' : '') + '<span class="tag">' + CS.esc(s.genre) + '</span>' + (s.mood ? '<span class="tag">' + CS.esc(s.mood) + '</span>' : '') + s.mode.map(CS.modeTag).join('') + '</div>' +
    '<div class="price"><span class="faint">희망가</span><b>' + CS.won(s.price) + '</b></div></div></a>';
};
CS.top = function(on){
  var items = [['cs_index.html','둘러보기'],['cs_pass.html','청취권'],['cs_apply.html','곡 등록 신청'],['cs_talk.html','협상방'],['cs_admin.html','심사함']];
  var h = '<header class="top"><div class="wrap"><a class="logo" href="cs_index.html"><span class="bar"><i style="height:45%"></i><i style="height:80%"></i><i style="height:60%"></i><i style="height:100%"></i></span>첫소절<small>새 노래가 처음 울리는 곳</small></a><nav class="nav">' +
    items.map(function(x){ return '<a href="' + x[0] + '"' + (x[0] === on ? ' class="on"' : '') + '>' + x[1] + '</a>'; }).join('') +
    '<a class="cta" id="csLogin" href="cs_login.html">로그인</a></nav></div></header>';
  document.body.insertAdjacentHTML('afterbegin', h);
  CS.me().then(function(m){ var a = document.getElementById('csLogin'); if (!a) return;
    var adm = document.querySelector('.nav a[href="cs_admin.html"]'); if (adm && !(m.profile && (m.profile.role === 'admin' || m.profile.role === 'reviewer'))) adm.style.display = 'none';
    if (m.user) { a.textContent = '👤 ' + (m.profile ? m.profile.nickname : '내 정보'); a.href = 'cs_me.html'; }
    else a.href = 'cs_login.html?next=' + encodeURIComponent(location.pathname.split('/').pop() + location.search); });
  document.body.insertAdjacentHTML('beforeend', (['cs_talk.html','cs_pass.html'].indexOf(on) >= 0 ? '<div class="preview">미리보기 · 준비 중인 화면입니다</div>' : '') +
    '<footer class="foot wrap"><b>첫소절(위브앱솔루션)은 통신판매중개자이며 통신판매의 당사자가 아닙니다. 곡, 곡 정보, 거래에 관한 의무와 책임은 판매자(작가)에게 있습니다.</b><br>' +
    '위브앱솔루션 · 대표 이미화 · 사업자등록번호 206-08-71754 · 통신판매업신고 2022-수원권선-1701<br>경기도 수원시 권선구 수성로47 10동 501호 · weapps.kr@gmail.com<br>' +
    '<a href="cs_terms.html">이용약관</a> · <b><a href="cs_privacy.html">개인정보처리방침</a></b> · <a href="cs_terms.html#author">작가 약관</a> · <a href="cs_terms.html#refund">취소 · 환불 규정</a></footer>');
};

/* ── 로그인 · 회원 정보 (Supabase) ── */
CS.diag = { ev: [] };
try { localStorage.setItem('cs_ls_test', '1'); CS.diag.ls = localStorage.getItem('cs_ls_test') === '1' ? 1 : 0; CS.diag.key = Object.keys(localStorage).some(function(k){ return /^sb-.*auth-token$/.test(k); }) ? 1 : 0; } catch (e) { CS.diag.ls = 0; CS.diag.key = 0; }
CS.sb = (window.supabase && window.CS_SUPABASE_URL) ? window.supabase.createClient(window.CS_SUPABASE_URL, window.CS_SUPABASE_KEY) : null;
CS._me = null;
if (CS.sb) CS.sb.auth.onAuthStateChange(function(ev){ CS.diag.ev.push(ev); });
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
  if (m.user && m.err) { var bx = document.querySelector('main') || document.body; bx.insertAdjacentHTML('afterbegin', '<div class="card" style="margin:24px 0;padding:18px;color:var(--coral);line-height:1.7">회원 정보를 불러오지 못했습니다. 이 화면을 캡처해서 보내 주세요.<br><span class="faint">' + CS.esc(m.err) + '</span></div>'); return null; }
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
CS.PAL = {
  dark: { navy:['남색','#0E1020','#171A2E','#1F2340'], wine:['와인','#1A0E14','#26151D','#331C27'], forest:['숲','#0B1613','#13221D','#1A2D27'],
          violet:['보라','#130E22','#1D1633','#271E44'], ink:['먹색','#101010','#1A1A1A','#252525'] },
  light:{ ivory:['아이보리','#F6F2E9','#FFFDF8','#EFE9DC'], sky:['하늘','#EDF3FA','#FFFFFF','#E2EBF5'], pink:['벚꽃','#FAEFF1','#FFFFFF','#F3E1E5'],
          mint:['민트','#ECF6F1','#FFFFFF','#DDEEE6'], white:['흰색','#F7F7F8','#FFFFFF','#ECECEF'] } };
CS.FX = [['notes','🎵 음표'],['none','없음'],['snow','❄ 눈'],['rain','🌧 비'],['petal','🌸 벚꽃'],['stars','✨ 별밤'],['xmas','🎄 크리스마스']];
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
  st.setProperty('--staff', L ? 'rgba(60,50,30,.07)' : 'rgba(232,182,90,.07)');
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
  function count(){ var a = W * H / 1e4; return Math.round(Math.min(140, a * ({ snow:.55, rain:.9, petal:.25, stars:1.1, xmas:.5, notes:.12 })[kind])) || 0; }
  function make(init){
    var L = CS.isLight(), o = { x: R(0, W), y: init ? R(0, H) : -20 };
    if (kind === 'snow' || kind === 'xmas') { o.r = R(1, 3.4); o.vy = R(.3, 1.1); o.vx = R(-.3, .3); o.ph = R(0, 6); o.c = L ? 'rgba(150,170,200,' : 'rgba(255,255,255,'; o.a = R(.4, .9); }
    else if (kind === 'rain') { o.l = R(10, 22); o.vy = R(7, 12); o.vx = -1.6; o.a = R(.15, .4); o.c = L ? 'rgba(70,100,150,' : 'rgba(170,200,255,'; }
    else if (kind === 'petal') { o.r = R(4, 8); o.vy = R(.5, 1.3); o.vx = R(.2, 1); o.rot = R(0, 6); o.vr = R(-.03, .03); o.ph = R(0, 6); o.a = R(.55, .9); }
    else if (kind === 'stars') { o.y = R(0, H); o.r = R(.4, 1.6); o.ph = R(0, 6); o.sp = R(.01, .04); }
    else if (kind === 'notes') { o.y = init ? R(0, H) : H + 30; o.g = '♪♫♩♬𝄞'[Math.floor(R(0, 4.99))]; o.s = R(16, 34); o.vy = -R(.2, .5); o.ph = R(0, 6); o.a = R(.08, .2); o.rot = R(-.3, .3); }
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
  box.innerHTML = '<h4>밝기</h4><div class="opts">' + [['auto','🕒 자동'],['light','☀ 주간'],['dark','🌙 야간']].map(function(x){ return '<span class="chip' + (d.mode === x[0] ? ' on' : '') + '" data-m="' + x[0] + '">' + x[1] + '</span>'; }).join('') + '</div>' +
    '<h4>바탕색 (' + (L ? '주간' : '야간') + ')</h4><div class="opts">' + Object.keys(pal).map(function(k){ return '<span class="sw' + (k === cur ? ' on' : '') + '" title="' + pal[k][0] + '" data-b="' + k + '" style="background:linear-gradient(135deg,' + pal[k][1] + ' 50%,' + pal[k][3] + ' 50%)"></span>'; }).join('') + '</div>' +
    '<h4>분위기</h4><div class="opts">' + CS.FX.map(function(x){ return '<span class="chip' + (d.fx === x[0] ? ' on' : '') + '" data-f="' + x[0] + '">' + x[1] + '</span>'; }).join('') + '</div>' +
    '<h4>배경</h4><div class="opts"><span class="chip' + (d.staff ? ' on' : '') + '" data-s="1">🎼 오선지 무늬</span></div>' +
    '<div class="hint" style="margin-top:12px">이 기기에만 저장됩니다.' + (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches ? ' 기기 설정(동작 줄이기) 때문에 움직이는 분위기는 꺼져 있습니다.' : '') + '</div>';
  box.querySelectorAll('[data-m]').forEach(function(e){ e.onclick = function(){ d.mode = e.dataset.m; CS.saveDeco(); }; });
  box.querySelectorAll('[data-b]').forEach(function(e){ e.onclick = function(){ if (CS.isLight()) d.light = e.dataset.b; else d.dark = e.dataset.b; CS.saveDeco(); }; });
  box.querySelectorAll('[data-f]').forEach(function(e){ e.onclick = function(){ d.fx = e.dataset.f; CS.saveDeco(); }; });
  box.querySelector('[data-s]').onclick = function(){ d.staff = !d.staff; CS.saveDeco(); };
};
document.addEventListener('DOMContentLoaded', function(){
  CS.fx.init(); CS.fx.set(CS.deco.fx);
  var b = document.createElement('button'); b.className = 'deco-btn'; b.title = '화면 꾸미기'; b.setAttribute('aria-label', '화면 꾸미기'); b.textContent = '🎨';
  var p = document.createElement('div'); p.className = 'deco'; p.id = 'deco';
  document.body.appendChild(b); document.body.appendChild(p);
  b.onclick = function(e){ e.stopPropagation(); p.classList.toggle('on'); CS.paintDeco(); };
  document.addEventListener('click', function(e){ if (p.classList.contains('on') && !p.contains(e.target) && e.target !== b) p.classList.remove('on'); });
  if (window.matchMedia) matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(){ if (CS.deco.mode === 'auto') CS.applyDeco(); });
  setInterval(function(){ if (CS.deco.mode === 'auto') CS.applyDeco(); }, 600000);
});
