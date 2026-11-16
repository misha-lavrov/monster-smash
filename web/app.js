// =====================================================================
//  🖥️ ЦЕ «ОБЛИЧЧЯ» ГРИ — JavaScript, що працює в браузері.
//  Воно малює монстра й анімації, а на питання «скільки шкоди?»
//  відповідає Java-сервер (файл src/Main.java). Правила гри — там, не тут!
// =====================================================================

const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const fmt = (n) => Number(n).toLocaleString('uk-UA');

let state = null;   // що ми знаємо про гру (воно приходить від сервера)
let busy = false;   // щоб не бити під час анімації смерті монстра

// ---------------------------------------------------------------------
//  Розмова з Java-сервером (її видно внизу сторінки)
// ---------------------------------------------------------------------
async function ask(method, url, body) {
  const started = performance.now();
  talk('out', '→ браузер питає:    ' + method + ' ' + url);
  const response = await fetch(url, { method, body, cache: 'no-store' });
  const text = await response.text();
  const ms = Math.max(1, Math.round(performance.now() - started));
  talk('in', '← Java відповідає: ' + response.status + ' · ' + ms + ' мс · ' + text);
  return JSON.parse(text);
}

function talk(kind, text) {
  const log = $('log');
  const line = document.createElement('div');
  line.className = kind;
  line.textContent = text;
  log.appendChild(line);
  while (log.children.length > 6) log.firstChild.remove();
}

// ---------------------------------------------------------------------
//  Малюємо
// ---------------------------------------------------------------------
function render(s, spawn) {
  const killsBefore = state ? state.kills : s.kills;
  state = s;
  $('hero').textContent = s.hero;
  $('kills').textContent = s.kills;
  if (s.kills > killsBefore) play($('kills'), 'bump', 450);
  $('monster').classList.remove('dead');
  $('monster').textContent = s.monster.emoji;
  $('monsterName').textContent = s.monster.name;
  setHp(s.hp, s.monster.maxHp);
  if (spawn) play($('monster'), 'spawn', 500);
}

function setHp(hp, max) {
  const percent = Math.max(0, Math.min(100, (hp / max) * 100));
  const fill = $('hpFill');
  fill.style.width = percent + '%';
  fill.dataset.level = percent > 50 ? 'ok' : percent > 25 ? 'mid' : 'low';
  $('hpText').textContent = fmt(Math.max(0, hp)) + ' / ' + fmt(max);
}

function play(element, cssClass, ms) {   // запускає CSS-анімацію спочатку
  element.classList.remove(cssClass);
  void element.offsetWidth;
  element.classList.add(cssClass);
  if (ms) setTimeout(() => element.classList.remove(cssClass), ms);
}

function floatNumber(damage, crit) {
  const el = document.createElement('div');
  el.className = 'floater' + (crit ? ' crit' : '');
  el.textContent = '-' + fmt(damage) + (crit ? ' КРИТ!' : '');
  el.style.setProperty('--x', Math.round(Math.random() * 120 - 60) + 'px');
  $('floaters').appendChild(el);
  setTimeout(() => el.remove(), 1000);
}

function burst() {                        // вибух, коли монстр помирає
  for (let i = 0; i < 12; i++) {
    const spark = document.createElement('span');
    spark.className = 'spark';
    spark.textContent = ['💥', '✨', '⭐'][i % 3];
    const angle = (Math.PI * 2 * i) / 12;
    const distance = 90 + Math.random() * 60;
    spark.style.setProperty('--dx', Math.round(Math.cos(angle) * distance) + 'px');
    spark.style.setProperty('--dy', Math.round(Math.sin(angle) * distance) + 'px');
    $('arena').appendChild(spark);
    setTimeout(() => spark.remove(), 900);
  }
}

// ---------------------------------------------------------------------
//  Гра: удар
// ---------------------------------------------------------------------
async function hit() {
  if (busy || !state) return;
  busy = true;
  try {
    const r = await ask('POST', '/api/hit');       // питаємо Java: що вийшло з удару?
    floatNumber(r.damage, r.crit);
    play($('monster'), 'hurt', 300);
    if (r.killed) {
      setHp(0, state.monster.maxHp);
      burst();
      $('monster').classList.add('dead');
      await sleep(900);
      render(r.state, true);                       // з'являється наступний монстр
    } else {
      render(r.state, false);
    }
  } catch (e) {
    // сервер не відповів — червоне попередження покаже watchServer()
  } finally {
    busy = false;
  }
}

$('hitBtn').addEventListener('click', () => { hit(); $('hitBtn').blur(); });
const typing = (e) => e.target.closest && e.target.closest('input, textarea');   // у полі вводу пробіл — це пробіл, а не удар
document.addEventListener('keydown', (e) => {
  if (typing(e)) return;
  if ((e.code === 'Space' || e.code === 'Enter') && !e.repeat) { e.preventDefault(); hit(); }
});
document.addEventListener('keyup', (e) => {
  if (typing(e)) return;
  if (e.code === 'Space' || e.code === 'Enter') e.preventDefault();
});

// ---------------------------------------------------------------------
//  🚩 Прапорець: дитина знаходить його в коді сторінки й здає серверу.
//  Перевіряє Java, а не браузер — так само, як у справжніх CTF.
// ---------------------------------------------------------------------
$('flagForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const input = $('flagInput');
  const answer = input.value.trim();
  if (!answer) return;
  try {
    const r = await ask('POST', '/api/flag', answer);
    if (r.ok) {
      $('flagMsg').hidden = true;
      input.value = '';
      celebrate();
    } else {
      input.classList.remove('wrong');
      void input.offsetWidth;
      input.classList.add('wrong');
      const msg = $('flagMsg');
      msg.textContent = 'Хм, не збігається. Перевір, чи скопійовано все — разом із OIPZ{ на початку та } в кінці.';
      msg.hidden = false;
      setTimeout(() => { msg.hidden = true; }, 5000);
    }
  } catch (err) {
    // сервер не відповів — червоне попередження покаже watchServer()
  }
});

function celebrate() {                     // вітання + дощ із емодзі
  $('win').hidden = false;
  const icons = ['🎉', '⭐', '🚩', '✨', '🏆', '💥'];
  for (let i = 0; i < 46; i++) {
    const piece = document.createElement('span');
    piece.className = 'confetti';
    piece.textContent = icons[i % icons.length];
    piece.style.left = Math.round(Math.random() * 96) + 'vw';
    piece.style.animationDuration = (2.4 + Math.random() * 2) + 's';
    piece.style.animationDelay = (Math.random() * 0.9) + 's';
    document.body.appendChild(piece);
    setTimeout(() => piece.remove(), 5500);
  }
}
$('winClose').addEventListener('click', () => { $('win').hidden = true; });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') $('win').hidden = true; });

// ---------------------------------------------------------------------
//  «Живе оновлення»: коли сервер перезапустився або файл змінився —
//  сторінка перезавантажується САМА. Тому F5 тиснути не треба 🙂
// ---------------------------------------------------------------------
let version = null;
let downSince = null;

async function watchServer() {
  try {
    const response = await fetch('/api/version?page=1', { cache: 'no-store' });   // ?page=1 — «це я, сторінка гри»
    const current = (await response.json()).version;
    if (version === null) version = current;
    else if (current !== version) { location.reload(); return; }
    downSince = null;
    $('banner').hidden = true;
  } catch (e) {
    if (downSince === null) downSince = Date.now();
    const banner = $('banner');
    const long = Date.now() - downSince > 7000;
    banner.hidden = false;
    banner.classList.toggle('error', long);
    banner.textContent = long
      ? '⚠️ Сервер не відповідає. Можливо, у коді помилка — перевір червоні місця в редакторі або повідомлення на екрані.'
      : '⏳ Сервер перезапускається…';
  }
}

// ---------------------------------------------------------------------
//  Старт
// ---------------------------------------------------------------------
ask('GET', '/api/state').then((s) => render(s, true)).catch(() => {});
setInterval(watchServer, 500);

console.log('%c🕵️ Привіт, хакере!', 'font-size:22px;font-weight:bold;color:#ffcc00');
console.log('Ти відкрив інструменти розробника (F12) — так роблять справжні дослідники кібербезпеки.\n' +
            'У цій грі сховано прапорець у форматі OIPZ{...}.\n' +
            'Підказка: подивись у вихідний код сторінки (Ctrl+U). Знайдеш — здай його внизу гри.');
