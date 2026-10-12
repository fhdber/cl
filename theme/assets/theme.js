/* CONTRABEATZ — theme.js (vanilla, kein Framework) */
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  /* ---------- Toast ---------- */
  let toastTimer;
  const toast = (msg) => {
    const el = $('[data-toast]');
    if (!el) return;
    el.textContent = msg;
    el.classList.add('is-visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('is-visible'), 2400);
  };

  /* ---------- Audio-Player ---------- */
  const player = $('[data-player]');
  const audio = player && $('[data-player-audio]', player);
  let currentSrc = null;

  const fmt = (s) => {
    if (!isFinite(s)) return '0:00';
    const m = Math.floor(s / 60);
    return `${m}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
  };

  const syncButtons = () => {
    const playing = audio && !audio.paused;
    $$('[data-play]').forEach((b) => {
      const active = b.dataset.src === currentSrc && playing;
      b.classList.toggle('is-playing', active);
      b.setAttribute('aria-pressed', active ? 'true' : 'false');
    });
    if (player) player.classList.toggle('is-playing', !!playing);
    $$('.card__media').forEach((m) => {
      const b = $('[data-play]', m);
      m.classList.toggle('is-playing', !!b && b.dataset.src === currentSrc && playing);
    });
  };

  const play = (btn) => {
    if (!audio) return;
    const src = btn.dataset.src;
    if (src === currentSrc) {
      audio.paused ? audio.play() : audio.pause();
      return;
    }
    currentSrc = src;
    audio.src = src;
    $('[data-player-title]', player).textContent = btn.dataset.title || '';
    $('[data-player-sub]', player).textContent = btn.dataset.sub || '';
    const img = $('[data-player-cover]', player);
    const fb = $('[data-player-cover-fallback]', player);
    if (btn.dataset.cover) { img.src = btn.dataset.cover; img.hidden = false; if (fb) fb.hidden = true; } else { img.hidden = true; if (fb) fb.hidden = false; }
    $('[data-player-cover-link]', player).href = btn.dataset.url || '#';
    player.classList.add('is-active');
    document.body.classList.add('has-player');
    audio.play().catch(() => toast('Preview konnte nicht geladen werden'));
  };

  if (audio) {
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-play]');
      if (!btn) return;
      e.preventDefault();
      e.stopPropagation();
      play(btn);
    });
    $('[data-player-toggle]', player).addEventListener('click', () => {
      if (!currentSrc) return;
      audio.paused ? audio.play() : audio.pause();
    });
    $('[data-player-close]', player).addEventListener('click', () => {
      audio.pause();
      player.classList.remove('is-active');
      document.body.classList.remove('has-player');
    });
    ['play', 'pause', 'ended'].forEach((ev) => audio.addEventListener(ev, syncButtons));
    audio.addEventListener('timeupdate', () => {
      const pct = audio.duration ? (audio.currentTime / audio.duration) * 100 : 0;
      $('[data-player-bar]', player).style.width = `${pct}%`;
      $$('.card__media.is-playing').forEach((m) => m.style.setProperty('--progress', `${pct}%`));
      $('[data-player-seek]', player).setAttribute('aria-valuenow', Math.round(pct));
      $('[data-player-time]', player).textContent = `${fmt(audio.currentTime)} / ${fmt(audio.duration)}`;
    });
    const seek = $('[data-player-seek]', player);
    seek.addEventListener('click', (e) => {
      if (!audio.duration) return;
      const r = seek.getBoundingClientRect();
      audio.currentTime = ((e.clientX - r.left) / r.width) * audio.duration;
    });
    seek.addEventListener('keydown', (e) => {
      if (!audio.duration) return;
      if (e.key === 'ArrowRight') audio.currentTime = Math.min(audio.duration, audio.currentTime + 5);
      if (e.key === 'ArrowLeft') audio.currentTime = Math.max(0, audio.currentTime - 5);
    });
    document.addEventListener('keydown', (e) => {
      if (e.code !== 'Space' || !currentSrc) return;
      if (e.target.closest('input, textarea, select, button, a, [contenteditable]')) return;
      e.preventDefault();
      audio.paused ? audio.play() : audio.pause();
    });
  }

  /* ---------- Mobile-Menü ---------- */
  const menu = $('[data-mobile-menu]');
  $$('[data-menu-open]').forEach((b) => b.addEventListener('click', () => {
    menu.classList.add('is-open');
    b.setAttribute('aria-expanded', 'true');
    document.documentElement.style.overflow = 'hidden';
  }));
  $$('[data-menu-close]').forEach((b) => b.addEventListener('click', () => {
    menu.classList.remove('is-open');
    $$('[data-menu-open]').forEach((o) => o.setAttribute('aria-expanded', 'false'));
    document.documentElement.style.overflow = '';
  }));

  /* ---------- Warenkorb ---------- */
  const drawer = () => $('[data-cart-drawer]');
  const openDrawer = () => {
    const d = drawer();
    if (!d) return;
    d.classList.add('is-open');
    d.setAttribute('aria-hidden', 'false');
    document.documentElement.style.overflow = 'hidden';
    const close = $('[data-drawer-close]', d);
    if (close) close.focus();
  };
  const closeDrawer = () => {
    const d = drawer();
    if (!d) return;
    d.classList.remove('is-open');
    d.setAttribute('aria-hidden', 'true');
    document.documentElement.style.overflow = '';
  };

  const renderSections = (sections) => {
    if (!sections) return;
    if (sections['cart-drawer']) {
      const html = new DOMParser().parseFromString(sections['cart-drawer'], 'text/html');
      const fresh = $('[data-cart-drawer-inner]', html);
      const cur = $('[data-cart-drawer-inner]');
      if (fresh && cur) cur.replaceWith(fresh);
    }
    const count = $('[data-drawer-count]');
    if (count) $$('[data-cart-count]').forEach((el) => { el.textContent = count.textContent; });
  };

  const cartRequest = async (url, body) => {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ ...body, sections: ['cart-drawer'], sections_url: window.location.pathname })
    });
    const data = await res.json();
    if (!res.ok || data.status) throw new Error(data.description || data.message || 'Fehler');
    return data;
  };

  document.addEventListener('submit', async (e) => {
    const form = e.target.closest('form[data-product-form]');
    if (!form || window.CB.cartType !== 'drawer') return;
    e.preventDefault();
    const btn = $('[type="submit"]', form);
    btn.classList.add('is-loading');
    try {
      const fd = new FormData(form);
      const data = await cartRequest(`${window.CB.routes.cartAdd}.js`, {
        items: [{ id: Number(fd.get('id')), quantity: Number(fd.get('quantity') || 1) }]
      });
      renderSections(data.sections);
      openDrawer();
    } catch (err) {
      toast(err.message);
    } finally {
      btn.classList.remove('is-loading');
    }
  });

  document.addEventListener('click', async (e) => {
    const opener = e.target.closest('[data-cart-open]');
    if (opener && window.CB.cartType === 'drawer' && drawer()) {
      e.preventDefault();
      openDrawer();
      return;
    }
    if (e.target.closest('[data-drawer-close]')) { closeDrawer(); return; }

    const change = e.target.closest('[data-line-change]');
    if (change) {
      e.preventDefault();
      try {
        const data = await cartRequest(`${window.CB.routes.cartChange}.js`, {
          line: Number(change.dataset.line), quantity: Number(change.dataset.qty)
        });
        if (drawer() && drawer().classList.contains('is-open')) renderSections(data.sections);
        else window.location.reload();
      } catch (err) { toast(err.message); }
    }
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeDrawer(); });

  /* ---------- Produktseite: Varianten + Galerie ---------- */
  $$('[data-product-form]').forEach((form) => {
    const radios = $$('input[name="id"][type="radio"]', form);
    const priceEl = $('[data-price]');
    const btnLabel = $('[type="submit"] .btn__label', form);
    radios.forEach((r) => r.addEventListener('change', () => {
      if (priceEl && r.dataset.price) priceEl.innerHTML = r.dataset.price;
      if (btnLabel) btnLabel.textContent = r.dataset.available === 'true' ? btnLabel.dataset.add : btnLabel.dataset.soldout;
      $('[type="submit"]', form).disabled = r.dataset.available !== 'true';
      const url = new URL(window.location.href);
      url.searchParams.set('variant', r.value);
      history.replaceState({}, '', url);
    }));
  });

  $$('[data-gallery]').forEach((g) => {
    const main = $('[data-gallery-main]', g);
    $$('[data-gallery-thumb]', g).forEach((t) => t.addEventListener('click', () => {
      $$('[data-gallery-thumb]', g).forEach((o) => o.setAttribute('aria-current', 'false'));
      t.setAttribute('aria-current', 'true');
      const img = $('img', main);
      if (img) { img.srcset = t.dataset.srcset; img.src = t.dataset.src; img.alt = t.dataset.alt || ''; }
    }));
  });


  /* ---------- Layout-Motion (aus Florians Layout) ---------- */
  const still = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Hero-Intro: CONTRA skaliert ein, danach wird der Tag Buchstabe für Buchstabe aufgesprüht
  $$('[data-stage]').forEach((st) => {
    requestAnimationFrame(() => requestAnimationFrame(() => st.classList.add('is-in')));
    const first = st.querySelector('animate[begin="indefinite"]');
    if (!still && first && first.beginElement) {
      $$('.cb-rv', st).forEach((r) => r.setAttribute('width', '0'));
      setTimeout(() => first.beginElement(), 720);
    }
  });

  // Hero-Parallaxe
  const mark = $('[data-stage-mark]');
  if (mark && !still) {
    let tick = false;
    const upd = () => {
      tick = false;
      mark.style.transform = window.innerWidth <= 820 ? '' : `translate(-50%, calc(-50% + ${window.scrollY * -0.05}px))`;
    };
    window.addEventListener('scroll', () => { if (!tick) { requestAnimationFrame(upd); tick = true; } }, { passive: true });
    window.addEventListener('resize', upd);
  }

  // Reveal der Sektionen, gestaffelt von oben nach unten
  if ('IntersectionObserver' in window && !still) {
    const STEP = 140;
    const io = new IntersectionObserver((es) => {
      es.filter((e) => e.isIntersecting)
        .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)
        .forEach((en, i) => {
          const d = `${(i * STEP) / 1000}s`;
          en.target.style.transitionDelay = d;
          en.target.style.animationDelay = d;
          en.target.classList.add('in');
          io.unobserve(en.target);
        });
    }, { threshold: 0.14 });
    $$('.fs-rv, .rvimg').forEach((el) => io.observe(el));
  } else {
    $$('.fs-rv').forEach((el) => el.classList.add('in'));
  }

  // Footer: CONTRA schiebt sich scroll-gekoppelt von oben in den Footer
  const foot = $('[data-footer]:not(.footer--static)');
  const word = foot && $('[data-fmk]', foot);
  if (word) {
    if (still) { word.style.transform = 'none'; } else {
      let tick = false;
      const markEl = $('.footer__mark', foot);
      const upd = () => {
        tick = false;
        const r = markEl.getBoundingClientRect(), vh = window.innerHeight;
        const p = Math.max(0, Math.min(1, (vh - r.top) / (vh * 0.6)));
        word.style.transform = `translateY(${-(1 - p) * 100}%)`;
      };
      window.addEventListener('scroll', () => { if (!tick) { requestAnimationFrame(upd); tick = true; } }, { passive: true });
      window.addEventListener('resize', upd);
      upd();
    }
  }

  // Footer: Bilder folgen der Maus über der Wortmarke
  const trail = $('[data-trail]');
  const pool = trail ? $$('.fmk-img', trail) : [];
  if (pool.length && !still) {
    let pi = 0, lx = 0, ly = 0, primed = false;
    trail.addEventListener('mousemove', (e) => {
      const r = trail.getBoundingClientRect();
      const x = e.clientX - r.left, y = e.clientY - r.top;
      if (!primed) { lx = x; ly = y; primed = true; }
      if (Math.hypot(x - lx, y - ly) < 70) return;
      lx = x; ly = y;
      const im = pool[pi++ % pool.length];
      const rot = (Math.random() * 10 - 5).toFixed(1);
      im.style.left = `${x}px`; im.style.top = `${y}px`;
      im.style.transition = 'none'; im.style.opacity = '0';
      im.style.transform = `translate(-50%,-50%) scale(.72) rotate(${rot}deg)`;
      void im.offsetWidth;
      im.style.transition = 'opacity .45s ease, transform .6s cubic-bezier(.16,1,.3,1)';
      im.style.opacity = '1';
      im.style.transform = `translate(-50%,-50%) scale(1) rotate(${rot}deg)`;
      clearTimeout(im._t);
      im._t = setTimeout(() => { im.style.opacity = '0'; im.style.transform = `translate(-50%,-50%) scale(.94) rotate(${rot}deg)`; }, 560);
    });
    trail.addEventListener('mouseleave', () => { primed = false; pool.forEach((im) => { im.style.opacity = '0'; }); });
  }

  /* ---------- Sortierung ---------- */
  $$('[data-sort]').forEach((sel) => sel.addEventListener('change', () => {
    const url = new URL(window.location.href);
    url.searchParams.set('sort_by', sel.value);
    url.searchParams.delete('page');
    window.location.href = url.toString();
  }));
})();
