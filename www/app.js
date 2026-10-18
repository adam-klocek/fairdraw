/* The server locks the result first. This 30-second reveal never selects a winner. */
window.Fairdraw = {
  rotation: 0, revealTimer: null, progressTimer: null, finishReveal: null,
  presentation: function () { document.getElementById('draw-card').classList.toggle('presentation'); },
  confetti: function () {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    for (let i = 0; i < 55; i++) {
      const piece = document.createElement('i'); piece.className = 'confetti';
      piece.style.left = (15 + Math.random() * 70) + '%';
      piece.style.background = ['#005b43', '#f6bb28', '#ef6a3d', '#6370d1', '#18a7c6'][i % 5];
      piece.style.setProperty('--drift', (Math.random() * 160 - 80) + 'px');
      piece.style.animationDelay = (Math.random() * 0.4) + 's';
      document.body.appendChild(piece); setTimeout(() => piece.remove(), 3600);
    }
  }
};
document.addEventListener('keydown', function (event) {
  if (event.key === 'Escape') document.getElementById('draw-card').classList.remove('presentation');
});
document.addEventListener('click', function (event) {
  if (event.target.closest('#skip-reveal') && Fairdraw.finishReveal) Fairdraw.finishReveal();
});
$(document).on('shiny:connected', function () {
  document.documentElement.lang = 'cs';
  Shiny.addCustomMessageHandler('fd-nav', function (view) {
    document.querySelectorAll('.nav-item').forEach(x => x.classList.remove('active'));
    const active = document.getElementById('nav_' + view); if (active) active.classList.add('active');
  });
  Shiny.addCustomMessageHandler('fd-result-visible', function (visible) {
    document.getElementById('draw-card').classList.toggle('has-result', visible);
  });
  Shiny.addCustomMessageHandler('fd-reveal', function (message) {
    const card = document.getElementById('draw-card'), button = document.getElementById('draw');
    const wheel = document.getElementById('wheel'), progress = document.getElementById('spin-progress');
    const countdown = document.getElementById('wheel-countdown'), fill = document.getElementById('spin-fill');
    clearTimeout(Fairdraw.revealTimer); clearInterval(Fairdraw.progressTimer);
    card.classList.remove('has-result'); card.setAttribute('aria-busy', 'true');
    button.disabled = true; button.classList.add('is-drawing');
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const duration = Math.max(1000, Math.min(60000, Number(message.duration) || 30000));
    const delay = message.mode === 'instant' || reduced ? 40 : duration;
    if (delay > 100 && typeof wheel.scrollIntoView === 'function') wheel.scrollIntoView({behavior: 'smooth', block: 'center'});
    progress.style.display = delay > 100 ? 'block' : 'none'; fill.style.width = '0%';
    wheel.style.transition = 'none'; void wheel.offsetWidth;
    wheel.style.transition = reduced ? 'none' : 'transform ' + (delay / 1000) + 's cubic-bezier(.15,.59,.23,1)';
    Fairdraw.rotation += 360 * 65 + 135; wheel.style.transform = 'rotate(' + Fairdraw.rotation + 'deg)';
    const start = performance.now(); let finished = false, previousSecond = -1;
    const update = function () {
      const elapsed = performance.now() - start, remaining = Math.max(0, Math.ceil((delay - elapsed) / 1000));
      fill.style.width = Math.min(100, elapsed / delay * 100) + '%';
      if (remaining !== previousSecond) { countdown.textContent = 'Zbývá ' + remaining + ' s / ' + remaining + ' s remaining'; previousSecond = remaining; }
    };
    Fairdraw.finishReveal = function () {
      if (finished) return; finished = true;
      clearTimeout(Fairdraw.revealTimer); clearInterval(Fairdraw.progressTimer);
      const current = getComputedStyle(wheel).transform; wheel.style.transition = 'none'; wheel.style.transform = current;
      Fairdraw.rotation = 0; progress.style.display = 'none'; card.setAttribute('aria-busy', 'false');
      Shiny.setInputValue('reveal_done', { token: message.token, at: Date.now() }, { priority: 'event' });
      button.disabled = false; button.classList.remove('is-drawing'); Fairdraw.finishReveal = null; Fairdraw.confetti();
    };
    update(); Fairdraw.progressTimer = setInterval(update, 200);
    Fairdraw.revealTimer = setTimeout(Fairdraw.finishReveal, delay);
  });
});
