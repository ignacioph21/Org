window.onload = function() {
  var overlay = document.createElement('div');
  overlay.id = 'lightbox';
  overlay.innerHTML = '<img id="lightbox-img" src="" />';
  document.body.appendChild(overlay);

  document.querySelectorAll('#content img').forEach(function(img) {
    img.addEventListener('click', function() {
      document.getElementById('lightbox-img').src = img.src;
      overlay.classList.add('active');
    });
  });

  overlay.addEventListener('click', function() {
    overlay.classList.remove('active');
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') overlay.classList.remove('active');
    if (e.key === 'ArrowLeft') followNavLink('.entry-nav-prev');
    if (e.key === 'ArrowRight') followNavLink('.entry-nav-next');
  });

  function followNavLink(selector) {
    if (overlay.classList.contains('active')) return; // don't hijack arrows while viewing an image
    var link = document.querySelector(selector);
    if (link && !link.classList.contains('disabled')) window.location.href = link.href;
  }

  initEntryNav();
};

// ── Inter-entry navigation (prev/next + weeks strip) ──
// Only runs on individual entry pages (they have #content); the index page does not.
function initEntryNav() {
  var content = document.getElementById('content');
  if (!content) return;

  fetch('../../../search-index.json')
    .then(function(res) { return res.json(); })
    .then(function(entries) { buildEntryNav(entries, content); })
    .catch(function() { /* nav is a nice-to-have; fail silently */ });
}

function buildEntryNav(entries, content) {
  // Chronological order: sort by year, then month, keeping original (stable) order within a month.
  var sorted = entries.slice().sort(function(a, b) {
    if (a.year !== b.year) return a.year < b.year ? -1 : 1;
    if (a.month !== b.month) return a.month < b.month ? -1 : 1;
    return 0;
  });

  var path = window.location.pathname;
  var currentIndex = -1;
  for (var i = 0; i < sorted.length; i++) {
    if (path.indexOf(sorted[i].url) !== -1) { currentIndex = i; break; }
  }
  if (currentIndex === -1) return;

  var prev = sorted[currentIndex - 1] || null;
  var next = sorted[currentIndex + 1] || null;

  var nav = document.createElement('div');
  nav.id = 'entry-nav';

  var row = document.createElement('div');
  row.className = 'entry-nav-row';
  row.appendChild(makeNavLink(prev, 'entry-nav-prev', 'prev'));
  row.appendChild(makeNavLink(next, 'entry-nav-next', 'next'));
  nav.appendChild(row);

  var strip = document.createElement('div');
  strip.className = 'entry-nav-strip';
  sorted.forEach(function(e, idx) {
    var chip = document.createElement('a');
    chip.className = 'entry-nav-chip' + (idx === currentIndex ? ' current' : '');
    chip.href = relativeUrl(e.url);
    chip.textContent = shortLabel(e.title);
    chip.title = e.title;
    strip.appendChild(chip);
  });
  nav.appendChild(strip);

  content.parentNode.insertBefore(nav, content.nextSibling);

  // keep the current chip in view
  var current = strip.querySelector('.current');
  if (current) current.scrollIntoView({ inline: 'center', block: 'nearest' });
}

function makeNavLink(entry, cls, dir) {
  var a = document.createElement('a');
  a.className = 'entry-nav-link ' + cls;
  if (!entry) {
    a.classList.add('disabled');
    a.href = '#';
    a.innerHTML = dir === 'prev' ? '&larr; &mdash;' : '&mdash; &rarr;';
    return a;
  }
  a.href = relativeUrl(entry.url);
  var arrow = dir === 'prev' ? '&larr; ' : ' &rarr;';
  var label = dir === 'prev' ? (arrow + entry.title) : (entry.title + arrow);
  a.innerHTML = label;
  return a;
}

function relativeUrl(url) {
  // search-index.json URLs are relative to the site root (same base as index.html);
  // entry pages sit 3 levels below that root (Lab-Journal-html/YYYY/MM/file.html).
  return '../../../' + url;
}

function shortLabel(title) {
  var m = title.match(/(\d+)/);
  if (m) return 'S' + m[1];
  var word = title.split(' ')[0];
  return word.length > 10 ? word.slice(0, 10) + '\u2026' : word;
}
