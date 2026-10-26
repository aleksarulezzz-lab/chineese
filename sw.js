/* Работа без интернета. Сначала сеть (чтобы всегда была свежая версия),
   при ошибке сети — последняя сохранённая копия. Прогресс здесь не хранится:
   он лежит в localStorage браузера и никуда не отправляется. */
const CACHE='hanzi-hero-v1';
const ASSETS=['./','manifest.webmanifest','icons/icon-192.png','icons/icon-512.png','icons/apple-touch-icon.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
  const r=e.request;
  const u=new URL(r.url);
  if(r.method!=='GET'||u.origin!==location.origin||u.pathname.includes('/api/'))return;
  e.respondWith(fetch(r).then(res=>{
    if(res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(r,copy))}
    return res;
  }).catch(()=>caches.match(r,{ignoreSearch:true})
    .then(hit=>hit||(r.mode==='navigate'?caches.match('./'):undefined))
    .then(hit=>hit||Response.error())));
});
