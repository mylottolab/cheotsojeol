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
CS.GENRES = ['전체','발라드','댄스','팝','R&B','어쿠스틱','록','트로트','광고 · 배경음악'];
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
